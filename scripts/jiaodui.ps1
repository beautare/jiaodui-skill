<#
// jiaodui.ps1 — 校对助手 CLI（Windows PowerShell 5.1+）
// 调用 OpenAI 兼容接口 https://jd.glowjames.top/v1/chat/completions
//
//   .\jiaodui.ps1 "他慢慢的走了。"
//   .\jiaodui.ps1 -File draft.md
//   "文本" | .\jiaodui.ps1
//   .\jiaodui.ps1 -File draft.md -Json
//   .\jiaodui.ps1 -TextModel "他慢慢的走了。"
//
// key 读取顺序：-Key 参数 → $env:JIAODUI_API_KEY 环境变量 → 脚本目录向上查找 .env。
// 没有 key 请先免费注册：https://jd.glowjames.top/register
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Text = "",
  [Parameter()][string]$File = "",
  [Parameter()][switch]$Json,
  [Parameter()][switch]$TextModel,
  [Parameter()][string]$Model = "jiaodui",
  [Parameter()][string]$Key = "",
  [Parameter()][string]$Url = "https://jd.glowjames.top/v1/chat/completions"
)

$ErrorActionPreference = "Stop"

function Show-Usage {
  @"
用法：
  .\jiaodui.ps1 "要校对的中文文本"
  .\jiaodui.ps1 -File draft.md [-Json] [-TextModel]
  "文本" | .\jiaodui.ps1

选项：
  -File FILE   校对文件内容
  -Json        输出原始 JSON（默认输出可读报告）
  -TextModel   使用 jiaodui-text 模型（可读文本报告）
  -Model NAME  指定模型（jiaodui / jiaodui-text / jiaodui-json）
  -Key KEY     显式指定 API key（默认读环境变量 / .env）
  -Url URL     覆盖 API 端点

key 读取顺序：-Key → `$env:JIAODUI_API_KEY → 脚本目录向上查找 .env。
免费注册拿 key：https://jd.glowjames.top/register
"@
}

function Get-DotEnvKey([string]$Name) {
  $d = $PSScriptRoot
  while ($d) {
    $p = Join-Path $d ".env"
    if (Test-Path $p) {
      foreach ($line in (Get-Content $p)) {
        $t = $line.Trim()
        if ($t.StartsWith($Name + "=")) {
          $v = $t.Substring($Name.Length + 1).Trim().Trim('"').Trim("'")
          if ($v) { return $v }
        }
      }
    }
    $parent = Split-Path $d -Parent
    if ((-not $parent) -or ($parent -eq $d)) { break }
    $d = $parent
  }
  return ""
}

# ---- 输入：文件 > 参数 > stdin 管道 ----
if ($File) {
  if (-not (Test-Path $File -PathType Leaf)) { Write-Error "文件不存在：$File"; exit 2 }
  $Text = Get-Content $File -Raw -Encoding UTF8
}
elseif ((-not $Text) -and [Console]::IsInputRedirected) {
  $Text = [Console]::In.ReadToEnd()
}
if (-not $Text) { Show-Usage; exit 2 }

# ---- key：参数 > 环境变量 > 向上查找 .env ----
if (-not $Key) { $Key = $env:JIAODUI_API_KEY }
if (-not $Key) { $Key = Get-DotEnvKey "JIAODUI_API_KEY" }
if (-not $Key) {
  Write-Error '未找到 JIAODUI_API_KEY。请先免费注册拿 key（https://jd.glowjames.top/register），再设置环境变量：$env:JIAODUI_API_KEY = "你的 key"；或本次显式传入：.\jiaodui.ps1 -Key <key> "文本"'
  exit 2
}

if ($TextModel) { $Model = "jiaodui-text" }

$body = @{
  model    = $Model
  messages = @(@{ role = "user"; content = $Text })
  stream   = $false
} | ConvertTo-Json -Depth 5 -Compress

try {
  $resp = Invoke-RestMethod -Method Post -Uri $Url `
    -Headers @{ Authorization = "Bearer $Key"; "User-Agent" = "jiaodui.ps1/1.0" } `
    -ContentType "application/json; charset=utf-8" -Body $body -TimeoutSec 60
}
catch {
  $code = 0
  try { $code = [int]$_.Exception.Response.StatusCode.value__ } catch { }
  if ($code -eq 401) { Write-Error "key 无效或已过期（HTTP 401）。请去个人中心重新生成：https://jd.glowjames.top/portal"; exit 1 }
  if ($code -eq 429) { Write-Error "触发限流（每个 key 2 QPS），请稍后重试（HTTP 429）。"; exit 1 }
  Write-Error ("请求失败（HTTP {0}）：{1}" -f $code, $_.Exception.Message)
  exit 1
}

$content = $resp.choices[0].message.content
if ($null -eq $content) {
  $resp | ConvertTo-Json -Depth 10
  exit 0
}

if ($Json) {
  try { $content | ConvertFrom-Json | ConvertTo-Json -Depth 10 } catch { $content }
  exit 0
}

# 默认：可读报告。content 为结构化 JSON 时渲染，否则（jiaodui-text）原样输出。
try {
  $r = $content | ConvertFrom-Json
}
catch {
  $content
  exit 0
}

$items = @($r.items)
if ($items.Count -eq 0) { "本次校对未发现差错。"; exit 0 }

$total = $r.total
if ($null -eq $total) { $total = $items.Count }
"发现 $total 条："
foreach ($it in $items) {
  $w = $it.wrong; if (-not $w) { $w = $it.c2 }
  $s = $it.suggestion; if (-not $s) { $s = $it.c3 }
  "  $w → $s"
}
