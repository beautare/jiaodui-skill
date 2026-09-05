# 校对助手 Skill（开源，MIT）

把中文校对做成可随时调用的能力：同一引擎，四种接入（CLI / API / Skill / MCP），开箱即用。

- 官网：https://jd.glowjames.top
- 免费注册拿 key：https://jd.glowjames.top/register（注册即得一个免费 key）
- 无差错时输出 `本次校对未发现差错。`

## 你是哪类用户？三选一

### A. 在 AI 对话里用 —— 远端 MCP（推荐，零安装）

往你的 AI 客户端贴一个 URL + key 即可，不用装任何东西：

```json
{ "mcpServers": { "jiaodui": {
  "url": "https://jd.glowjames.top/mcp",
  "headers": { "Authorization": "Bearer 你的 key" }
} } }
```

然后直接说"帮我校对这段"。Claude / Cursor / VS Code 等支持 MCP 的客户端均可。

### B. 写作者 / 批量处理 —— CLI 三脚本（免装 Python 包）

```bash
# macOS / Linux（依赖 curl + python3，仅用于组装/解析 JSON）
export JIAODUI_API_KEY="你的 key"
./scripts/jiaodui.sh "他慢慢的走了。"

# Windows PowerShell
$env:JIAODUI_API_KEY = "你的 key"
.\scripts\jiaodui.ps1 "他慢慢的走了。"

# Windows cmd（转调 ps1）
.\scripts\jiaodui.cmd "他慢慢的走了。"
```

输出：

```
发现 1 条：
  慢慢的走 → 慢慢地走
```

更多参数（校对文件 `-f`、管道、JSON 输出）：见 `SKILL.md`。

### C. 自己编译 / 审计源码 —— 本地 MCP（需 Go 1.25+）

`mcp-server/` 是零依赖自包含源码（除 `go-sdk`），三系统同一条命令：

```bash
cd mcp-server
go build -o jiaodui-mcp .
```

配 stdio（key 换自己的）：

```json
{ "mcpServers": { "jiaodui": {
  "command": "/path/to/jiaodui-mcp",
  "env": { "JIAODUI_API_KEY": "你的 key" }
} } }
```

本地版经远端 API 调用，不内置任何 key，缺 key 时报错指引注册。

---

## 文件

| 文件 | 说明 |
|---|---|
| `SKILL.md` | skill 定义全文：CLI / MCP / API 直调（AI 客户端可直接加载） |
| `scripts/jiaodui.sh` | macOS / Linux CLI |
| `scripts/jiaodui.ps1` | Windows PowerShell CLI |
| `scripts/jiaodui.cmd` | Windows cmd 包装入口 |
| `scripts/beautare_client.py` | 调试脚本：打印 OpenAI 风格原始响应 |
| `scripts/setup_env.py` | 写 key 到本目录 `.env`（不改你的 shell 配置） |
| `mcp-server/` | 本地 MCP 自包含源码（`go build` 即得） |
| `references/api.md` | OpenAI 兼容接口参数 / 限制 / 错误码 |

## key 与限制

- 读取顺序：`--key` 参数 → `$JIAODUI_API_KEY` 环境变量 → 本仓库根目录 `.env`
- 单次输入 ≤ 40,000 字；HTTP body ≤ 1MB
- 每个 key 限流 2 QPS（超限 429）；每个账户最多 5 个有效 key
- key 丢失/泄漏：去[个人中心](https://jd.glowjames.top/portal)吊销重建

## License

MIT，见 [LICENSE](LICENSE)。
