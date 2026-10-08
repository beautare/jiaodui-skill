# CLI 使用参考

所有脚本路径以实际 Skill 根目录为基准，不假设当前工作目录。

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



## 调试

仅在排查响应问题时使用 `scripts/beautare_client.py`，支持 `--text` 和 `--stream`。不要开启会打印凭据或请求头的调试输出。
