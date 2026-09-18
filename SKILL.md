---
name: jiaodui-skill
description: >
  中文校对（错别字、同音/形近字、的/地/得、标点与引号配对）。Use when 用户要求
  校对中文、找错别字、检查标点，或写作 / 编辑审稿 / 发布前检查 / 批量稿件流程中
  需要中文文本校对。同一引擎提供 CLI / MCP / OpenAI 兼容 API 三种接入，本 skill
  含全部用法与脚本。不适用于代码、公式、英文（或非中文）文本，也不做翻译与改写。
---

# 校对助手 —— 中文校对能力

> 更新日期：2026-09-18。开源仓库：https://github.com/beautare/jiaodui-skill（MIT）。
> 本文只讲用法；**限流、长度上限、Key 数量等数值以 `references/api.md` 为准**（单点维护，避免多处漂移）。

## 什么时候用 / 什么时候不用

**用**：中文文本的错别字与同音/形近字误用（在/再、的/地/得）、标点与引号配对、数字与序号、命名顺序、重复字符；写作者自查、编辑审稿、发布前把关、批量稿件、编辑器保存钩子。

**不用**：

- 英文或其他语言的拼写语法检查（本引擎面向中文）
- 代码、公式、JSON / 配置 / 日志（不要把代码当文章校对）
- 翻译、润色重写、内容生成（这是**校对**：只给「原文 → 建议」，不做改写）
- 事实核查、合规判断、观点评价（需要人工或其他手段）

## 任务 → 入口（先选一条）

| 你的场景 | 用什么 | 看本文哪节 |
|---|---|---|
| 在 AI 对话里随手校对 | 远端 MCP（零安装，贴 URL + Key） | MCP 接入 · A |
| 终端/脚本校一个文件或一段文本 | CLI 三系统脚本 | 快速使用 |
| 要一份给人看的可读报告 | `model = jiaodui-text` | API 直调 |
| 程序化处理、要定位回写原文 | `model = jiaodui`（带 `offset`） | 结果怎么用 |
| 要审计/自行编译源码 | `mcp-server/`（Go 1.25+） | MCP 接入 · B |

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

完整参数参考见 `references/api.md`（数值口径的唯一事实源）。要点：

- **URL**: `https://jd.glowjames.top/v1/chat/completions`（POST）
- **Auth**: `Authorization: Bearer <你的 Key>`（不要把 Key 提交到代码仓库）
- **`model`**: `jiaodui`（默认，结构化 JSON）/ `jiaodui-text`（可读文本报告）/ `jiaodui-json`（`jiaodui` 别名）
- **`messages`**: 数组，取最后一个 `role=user` 的消息作为待校对文本
- **Limits**: 见 `references/api.md` 的「限制」表（长度上限、限流、Key 数量、超时）

## 结果怎么用

三种接入返回的是同一份结果，按用途选形态：

1. **给人看** → 用 `jiaodui-text`，`content` 就是报告文本，直接展示，不必二次解析。
2. **给程序用** → 用 `jiaodui`（默认）。`content` 是 JSON 字符串：

   ```json
   { "file": "", "total": 1,
     "items": [ { "index": 1, "wrong": "慢慢的走", "suggestion": "慢慢地走",
                  "type": "general", "offset": 2 } ] }
   ```

   - `index` 从 1 起；`type` 可能省略；`total` 为该次建议总数。
   - `offset` 是 `wrong` **首个字符在原文中的位置**（按 Unicode 字符计，从 1 起）。
     例：`他慢慢的走了。` 返回 `offset: 2`，对应第 2 个字符起的 `慢慢的走`。

3. **回写原文**（批量/管线场景）：

   - 用 `offset` 定位，**不要**用 `wrong` 做字符串搜索——同一串可能在原文多次出现，搜到的未必是这一处。
   - 同一次结果里有多条时，**从后往前**替换（先改 `offset` 大的），否则前面的替换会让后面所有 `offset` 失效。
   - 建议是**候选**不是判决：可以部分采纳；`wrong`/`suggestion` 为空或相等的条目跳过。
   - 若要精确定位替换范围，按字符（rune）切片而不是按字节，中文一个字算一个字符。

## 失败怎么处理

不要盲目重试，也不要**在网络/服务失败时报「未发现差错」**——那会把失败伪装成"文本没问题"。逐类处置：

| 现象 | 含义 | 处置 |
|---|---|---|
| 401 `invalid_api_key`（MCP 为纯文本 `Invalid API key`） | Key 缺失、失效或已吊销 | 去 https://jd.glowjames.top/portal 吊销旧的并重建；换 Key 重试，别重复用同一个 |
| 429 `rate_limit_exceeded`，带 `Retry-After`（MCP 同样带头，错误体为纯文本） | 触发限流 | 按 `Retry-After` 等待后重试；批量场景改成串行并主动间隔，不要并发轰炸 |
| 400 `context_length_exceeded` | 单次输入超上限 | 按段落/句子切分（切点选句末标点，避免切断词），逐块校对后合并 |
| 400 `body_too_large` | 请求体超上限 | 同样分批发送 |
| 400 `parameter_missing` | `messages` 里没有 `role=user` | 修正请求体 |
| 504 `timeout` | 服务端处理超时 | 缩短本次输入或稍后重试 |
| 网络错误 / 连接失败 | 服务不可达 | 稍后重试并如实告知用户"校对未完成"；不要把连接失败当成无差错 |

同一份文本尽量**一次提交、一次结果**：分块会丢掉跨块语境的检查（如引号配对、跨句的/地/得）。

## 调试脚本

在 skill 根目录下运行。`scripts/beautare_client.py` 打印 OpenAI 风格原始响应（Key 从 `.env` / 环境变量读取，或 `--key` 显式传）：

```bash
# Non-streaming
python scripts/beautare_client.py --text "他慢慢的走了。"

# Streaming
python scripts/beautare_client.py --text "他慢慢的走了。" --stream
```

## Key 与环境变量

Key 推荐放在 `$JIAODUI_API_KEY` 环境变量。`scripts/setup_env.py` 只写 skill 根目录 `.env`
（不会改你的 shell profile，需要持久化请按它打印的提示手动执行）：

```bash
python scripts/setup_env.py --key "<your_api_key>"
```

**Key 安全**：不要把 Key 写进代码、提交到 Git、粘贴进对话或日志；不要用会打印请求头的调试方式（如 `curl -v`、`set -x`）。本仓库 `.gitignore` 已忽略 `.env`。

## AI 自动配置（For AI Agents）

用户要求 AI 配置 Key 时：

1. 请用户提供 API Key（或取前文已出现的）。
2. 用终端工具运行 `python scripts/setup_env.py --key "<api_key>"`（只写 `.env`）。
3. 告诉用户配置完成；如需当前 shell 生效，手动 `export JIAODUI_API_KEY="<key>"`。
4. **不要在回复、日志或命令回显中重复这个 Key**。
