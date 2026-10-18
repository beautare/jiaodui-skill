# 校对助手 Skill

把中文校对做成可随时调用的能力：同一引擎，四种接入（CLI / API / Skill / MCP），开箱即用。
本仓库提供 CLI、Agent Skill 与 MCP 三种接入的实现，并附 API 直调说明。

- 官网：https://jd.glowjames.top
- 免费注册拿 Key：https://jd.glowjames.top/register


## 选择接入方式

### A. 在 AI 对话里用 —— 远端 MCP（零安装）

往你的 AI 客户端做如下配置：

```json
{ "mcpServers": { "jiaodui": {
  "url": "https://jd.glowjames.top/mcp",
  "headers": { "Authorization": "Bearer 你的 Key" }
} } }
```
其中 Key 按上文方式获取。

然后在你的 AI 客户端直接说“帮我校对这段：xxxx”。Claude / Cursor / VS Code / Codex 等支持 MCP 的客户端均可。

### B. CLI 三脚本（写作者 / 批量处理）

```bash
# macOS / Linux（依赖 curl + python3，仅用于组装/解析 JSON）
export JIAODUI_API_KEY="你的 Key"
./scripts/jiaodui.sh "他慢慢的走了。"

# Windows PowerShell
$env:JIAODUI_API_KEY = "你的 Key"
.\scripts\jiaodui.ps1 "他慢慢的走了。"

# Windows cmd（转调 ps1）
.\scripts\jiaodui.cmd "他慢慢的走了。"
```

输出：

```
发现 1 条：
  慢慢的走 → 慢慢地走
```

更多参数（校对文件 `-f`、管道、JSON 输出）：见 [CLI 参考](references/cli.md)。

### C. 本地 MCP —— npx 启动（无需编译）

需要 Node.js 18+，支持 macOS、Linux、Windows 的 x64 / ARM64，无需安装 Go。[npm 包](https://www.npmjs.com/package/jiaodui-mcp)由主仓库构建发布。

```json
{
  "mcpServers": {
    "jiaodui": {
      "command": "npx",
      "args": ["-y", "jiaodui-mcp"],
      "env": { "JIAODUI_API_KEY": "你的 Key" }
    }
  }
}
```

检查安装：`npx -y jiaodui-mcp --version`；MCP 客户端启动时会自动拉起 stdio 服务。

本地 MCP 仍会将校对文本发送至远端 API，不是离线引擎；不内置 Key，只读取环境变量，不自动读取 Skill 的 `.env`。

### D. 从源码编译（开发者可选）

需要 Go 1.25+；在本仓库的 `mcp-server/` 内运行 `go build -o jiaodui-mcp .`（Windows 可指定 `-o jiaodui-mcp.exe`）。
将 MCP 配置中的 `command` 换成生成文件的绝对路径，移除 npx 的 `args`，保留 `env`。详见 [配置指南](references/setup.md)。

---

## 文件

| 文件 | 说明 |
|---|---|
| `SKILL.md` | Agent 执行入口：适用范围、入口选择、执行与交付规则 |
| `scripts/jiaodui.sh` | macOS / Linux CLI |
| `scripts/jiaodui.ps1` | Windows PowerShell CLI |
| `scripts/jiaodui.cmd` | Windows cmd 包装入口 |
| `scripts/beautare_client.py` | 调试脚本：打印 OpenAI 风格原始响应 |
| `scripts/setup_env.py` | 写 key 到本目录 `.env`（不改你的 shell 配置） |
| `mcp-server/` | 本地 MCP 自包含源码（`go build` 即得） |
| `references/setup.md` | 首次配置、MCP 接入与连接验证 |
| `references/cli.md` | CLI 参数与使用示例 |
| `references/api.md` | OpenAI 兼容接口参数 / 限制 / 错误码 |

## Key 与限制

- CLI 的 Key 读取顺序：`--key` 参数 → `$JIAODUI_API_KEY` 环境变量 → 本仓库根目录 `.env`
- 单次输入 ≤ 40,000 字；HTTP body ≤ 1MB
- 限流：每 Key 每 2 秒 1 次（30 次/分钟，突发上限 4），超限返回 429（响应带 `Retry-After: 2`）
- 每账户 1 个有效 Key，更换时先在个人中心吊销旧的再创建新的
- Key 丢失/泄漏：去[个人中心](https://jd.glowjames.top/portal)吊销重建

## License

MIT，见 [LICENSE](LICENSE)。
