// Package main 实现 jiaodui-mcp：校对助手的本地 MCP server（stdio），自包含零依赖版（除 go-sdk）。
//
// 通过 stdio 暴露一个 proofread 工具，AI 客户端（Claude / Cursor / VS Code 等）
// 配置本 server 后即可在对话中调用中文校对能力。
//
// 本地版内部调用远端 OpenAI 兼容接口（默认 https://jd.glowjames.top/v1/chat/completions），
// key 来自 JIAODUI_API_KEY 环境变量（免费注册获取：https://jd.glowjames.top/register）。
// 为防止 key 泄漏与被刷流量，本程序不内置任何默认 key，缺 key 时直接报错指引用户注册。
//
// 另有零安装的远端 MCP（服务端直连引擎，无需本程序）：
// POST https://jd.glowjames.top/mcp（Streamable HTTP，Bearer key 鉴权），见 SKILL.md。
//
// 构建（需 Go 1.25+，任一操作系统）：
//
//	go build -o jiaodui-mcp .
//
// 或编译后由 MCP 客户端以 stdio 方式拉起。
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

const (
	defaultURL = "https://jd.glowjames.top/v1/chat/completions"
)

// ProofreadArgs 是 proofread 工具的输入参数。
// 未标 omitempty 的字段自动成为 JSON Schema 的 required 项。
type ProofreadArgs struct {
	Text string `json:"text" jsonschema:"要校对的中文文本"`
}

// chatRequest 是 OpenAI 兼容请求体。
type chatRequest struct {
	Model    string    `json:"model"`
	Messages []message `json:"messages"`
	Stream   bool      `json:"stream"`
}

type message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// chatResponse 是 OpenAI 兼容响应体。
type chatResponse struct {
	Choices []struct {
		Message message `json:"message"`
	} `json:"choices"`
}

// modernResult 是 jiaodui 模型的 content 结构化 JSON。
type modernResult struct {
	Total int `json:"total"`
	Items []struct {
		Wrong      string `json:"wrong"`
		Suggestion string `json:"suggestion"`
	} `json:"items"`
}

// toolError 构造一个 isError=true 的工具结果。
func toolError(msg string) *mcp.CallToolResult {
	return &mcp.CallToolResult{
		Content: []mcp.Content{&mcp.TextContent{Text: msg}},
		IsError: true,
	}
}

// proofread 是本地 MCP 工具处理函数：调远端 completions 接口，结果渲染成可读文本。
func proofread(ctx context.Context, req *mcp.CallToolRequest, args ProofreadArgs) (*mcp.CallToolResult, any, error) {
	text := strings.TrimSpace(args.Text)
	if text == "" {
		return toolError("校对文本为空"), nil, nil
	}

	apiKey := os.Getenv("JIAODUI_API_KEY")
	if apiKey == "" {
		return toolError("缺少 JIAODUI_API_KEY：请先免费注册拿 key（https://jd.glowjames.top/register），再在 MCP 客户端配置的 env 里设置 JIAODUI_API_KEY 后重试。"), nil, nil
	}
	url := os.Getenv("JIAODUI_API_URL")
	if url == "" {
		url = defaultURL
	}

	body, err := json.Marshal(chatRequest{
		Model:    "jiaodui",
		Messages: []message{{Role: "user", Content: text}},
		Stream:   false,
	})
	if err != nil {
		return toolError("构建请求失败：" + err.Error()), nil, nil
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return toolError("构建请求失败：" + err.Error()), nil, nil
	}
	httpReq.Header.Set("Content-Type", "application/json; charset=utf-8")
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)
	httpReq.Header.Set("User-Agent", "jiaodui-mcp/1.0 (+https://jd.glowjames.top)")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		return toolError("请求校对服务失败：" + err.Error()), nil, nil
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return toolError("读取响应失败：" + err.Error()), nil, nil
	}

	if resp.StatusCode != http.StatusOK {
		return toolError("校对服务返回错误（HTTP " + resp.Status + "）：" + string(respBytes)), nil, nil
	}

	var cr chatResponse
	if err := json.Unmarshal(respBytes, &cr); err != nil || len(cr.Choices) == 0 {
		return toolError("解析响应失败：" + string(respBytes)), nil, nil
	}

	out := formatRemoteResult(cr.Choices[0].Message.Content)
	return &mcp.CallToolResult{
		Content: []mcp.Content{&mcp.TextContent{Text: out}},
	}, nil, nil
}

// formatRemoteResult 把 completions 的 content（结构化 JSON 字符串或可读报告）转可读文本。
func formatRemoteResult(content string) string {
	var r modernResult
	if err := json.Unmarshal([]byte(content), &r); err != nil {
		return content // jiaodui-text 可读报告：原样返回
	}
	if r.Total == 0 || len(r.Items) == 0 {
		return "本次校对未发现差错。"
	}
	var b strings.Builder
	b.WriteString("发现 ")
	b.WriteString(itoa(r.Total))
	b.WriteString(" 条：\n")
	for _, it := range r.Items {
		b.WriteString("  ")
		b.WriteString(it.Wrong)
		b.WriteString(" → ")
		b.WriteString(it.Suggestion)
		b.WriteString("\n")
	}
	return b.String()
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}

func main() {
	local := mcp.NewServer(&mcp.Implementation{Name: "jiaodui-mcp", Version: "1.0.0"}, nil)
	mcp.AddTool(local, &mcp.Tool{
		Name:        "proofread",
		Description: "中文校对：输入中文文本，返回校对结果（原文→建议）。",
	}, proofread)

	if err := local.Run(context.Background(), &mcp.StdioTransport{}); err != nil {
		log.Printf("jiaodui-mcp server failed: %v", err)
	}
}
