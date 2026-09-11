---
name: beautare-jiaodui
description: 中文校对助手。Use when you need to proofread Chinese text or send text proofreading/completions requests to the OpenAI-compatible completions API endpoint at https://jd.glowjames.top/v1/chat/completions
---

# 校对助手 —— 中文校对能力

> 更新日期：2026-09-07。开源仓库：https://github.com/beautare/jiaodui-skill（MIT）。

## 快速使用（CLI 脚本，无需安装 Python 包）

三系统脚本位于 `scripts/`（macOS / Linux 版依赖 `curl` + `python3`，仅用于组装/解析 JSON；Windows 版为纯 PowerShell）：

```bash
# macOS / Linux
scripts/jiaodui.sh "他慢慢的走了。"

# Windows PowerShell
scripts/jiaodui.ps1 "他慢慢的走了。"

# Windows cmd（包装入口，转发给 jiaodui.ps1）
scripts/jiaodui.cmd "他慢慢的走了。"
```

常用参数：

```bash
# macOS / Linux（jiaodui.sh）
jiaodui.sh -f draft.md              # 校对文件
jiaodui.sh -f draft.md --json       # 原始 JSON 输出
jiaodui.sh --text-model "文本"       # 用 jiaodui-text 返回可读报告
echo "文本" | jiaodui.sh            # stdin 管道
jiaodui.sh --key <key>              # 显式指定 Key
jiaodui.sh --url <url>              # 覆盖 API 端点

# Windows PowerShell（jiaodui.ps1，参数同义）
jiaodui.ps1 -File draft.md          # 校对文件
jiaodui.ps1 -File draft.md -Json    # 原始 JSON 输出
jiaodui.ps1 -TextModel "文本"        # 用 jiaodui-text 返回可读报告
"文本" | jiaodui.ps1                # stdin 管道
jiaodui.ps1 -Key <key>              # 显式指定 Key
jiaodui.ps1 -Url <url>              # 覆盖 API 端点
```

输出示例：

```
发现 1 条：
  慢慢的走 → 慢慢地走
```

无差错时输出 `本次校对未发现差错。`。

Key 读取顺序：`--key`（sh）/ `-Key`（ps1）参数 → `$JIAODUI_API_KEY` 环境变量 → 脚本目录向上查找 `.env`。
没有 Key 请先免费注册：https://jd.glowjames.top/register（注册即得一个免费 Key）。

---

## MCP 接入（Claude / Cursor / VS Code 等）

`proofread` 工具，两种接法（同一引擎、同一 key 体系）：

### A. 远端（推荐，零安装）

服务端直连引擎，无需装任何东西。Streamable HTTP（POST，无状态），Bearer Key 鉴权：

```json
{
  "mcpServers": {
    "jiaodui": {
      "url": "https://jd.glowjames.top/mcp",
      "headers": { "Authorization": "Bearer 你的 Key" }
    }
  }
}
```

### B. 本地（自行编译，stdio）

本仓库 `mcp-server/` 是零依赖自包含源码（除 `go-sdk`），三系统同一条命令（需 Go 1.25+）：

```bash
cd mcp-server
go build -o jiaodui-mcp .
```

```json
{
  "mcpServers": {
    "jiaodui": {
      "command": "/path/to/jiaodui-skill/mcp-server/jiaodui-mcp",
      "env": { "JIAODUI_API_KEY": "你的 Key" }
    }
  }
}
```

本地版经远端 API 调用，不内置任何 Key，缺 Key 时报错指引注册。

### 工具

- **name**: `proofread`
- **input**: `{ "text": "要校对的中文文本" }`
- **output**: 人类可读的校对结果，如 `发现 1 条：\n  慢慢的走 → 慢慢地走`
- 无差错时返回 `本次校对未发现差错。`

本地版 Key 只读 `$JIAODUI_API_KEY` 环境变量（不读 `.env`）；`$JIAODUI_API_URL` 可覆盖 API 端点。

---

## API 直调（OpenAI 兼容协议）

完整参数参考见 `references/api.md`。要点：

- **URL**: `https://jd.glowjames.top/v1/chat/completions`（POST）
- **Auth**: `Authorization: Bearer <Key>`（门户注册获取，不要把 Key 提交到代码仓库）
- **`model`**: `jiaodui`（默认，结构化 JSON）/ `jiaodui-text`（可读文本报告）/ `jiaodui-json`（`jiaodui` 别名）
- **`messages`**: 数组，取最后一个 `role=user` 的消息作为待校对文本
- **Limits**: HTTP body ≤ 1MB；单次输入 ≤ 40,000 字；限流每 Key 每 2 秒 1 次（30 次/分钟，突发上限 4），超限 429（响应带 `Retry-After: 2`）；每账户 1 个有效 Key

## 调试脚本

在 skill 根目录下运行。`scripts/beautare_client.py` 打印 OpenAI 风格原始响应（Key 从 `.env` / 环境变量读取，或 `--key` 显式传）：

```bash
# Non-streaming
python scripts/beautare_client.py --text "他慢慢的走了。"

# Streaming
python scripts/beautare_client.py --text "他慢慢的走了。" --stream
```

## 环境变量配置

Key 推荐放在 `$JIAODUI_API_KEY` 环境变量。`scripts/setup_env.py` 只写 skill 根目录 `.env`
（不会改你的 shell profile，需要持久化请按它打印的提示手动执行）：

```bash
python scripts/setup_env.py --key "<your_api_key>"
```

## AI 自动配置（For AI Agents）

用户要求 AI 配置 `jiaodui-go` 的 Key 时：

1. 请用户提供 API Key（或取前文已出现的）。
2. 用终端工具运行 `python scripts/setup_env.py --key "<api_key>"`（只写 `.env`）。
3. 告诉用户配置完成；如需当前 shell 生效，手动 `export JIAODUI_API_KEY="<key>"`。
