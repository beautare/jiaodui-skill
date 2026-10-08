# 配置与连接验证

## Key 配置

Skill 免费开源，校对由在线 jiaodui API 执行。缺少 Key 时，指引用户前往 https://jd.glowjames.top/register 注册，并在本地填写；不要要求把 Key 粘贴进聊天。

- 优先使用已有环境变量或 `.env`，仅检查是否存在，不打印内容。
- CLI 的读取顺序见 [CLI 参考](cli.md)。本地 MCP 只读取环境变量，不读 `.env`。
- 用户在本地终端运行 `python3 scripts/setup_env.py`，通过隐藏输入写入 Skill 根目录 `.env`；Windows 使用本机 Python 启动命令。
- 脚本不修改 shell profile；`.env` 不会自动成为 MCP 进程的环境变量。
- 不将 Key 写入源码、提交到 Git、展示在聊天或日志。不使用 `curl -v`、`set -x` 等会回显请求头或凭据的调试方式。
- 凭据失效时前往 https://jd.glowjames.top/portal 管理，不反复使用失效 Key。

## 验证

配置后，用非敏感示例 `他慢慢的走了。` 发起一次请求。收到有效校对结果才报告连接成功；空输出、错误响应或解析失败不算成功。根据实际响应报告结果，不编造建议。

仅保存配置但未测试时，报告“配置已保存，连接尚未验证”。报告入口与配置文件位置，不显示 Key。安装或更新后，确认客户端发现 `jiaodui-skill`；若尚未刷新，提示重新加载，不能把文件已复制当作已加载。

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


