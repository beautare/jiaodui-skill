#!/usr/bin/env bash
#
# jiaodui.sh — 校对助手 CLI（macOS / Linux）
# 调用 OpenAI 兼容接口 https://jd.glowjames.top/v1/chat/completions
# 依赖：curl、python3
#
#   jiaodui.sh "他慢慢的走了。"
#   jiaodui.sh -f draft.md
#   echo "文本" | jiaodui.sh
#   jiaodui.sh -f draft.md --json
#   jiaodui.sh --text-model "他慢慢的走了。"
#
# key 读取顺序：--key 参数 → $JIAODUI_API_KEY 环境变量 → 脚本目录向上查找 .env。
# 没有 key 请先免费注册：https://jd.glowjames.top/register

set -u

PROG="jiaodui.sh"
DEFAULT_URL="https://jd.glowjames.top/v1/chat/completions"
DEFAULT_MODEL="jiaodui"

URL="$DEFAULT_URL"
MODEL="$DEFAULT_MODEL"
KEY=""
FILE=""
JSON_OUT=0
TEXT=""
SHOW_HELP=0

usage() {
  cat <<'EOF'
用法：
  jiaodui.sh "要校对的中文文本"
  jiaodui.sh -f draft.md [--json] [--text-model]
  echo "文本" | jiaodui.sh

选项：
  -f, --file FILE   校对文件内容
  --json            输出原始 JSON（默认输出可读报告）
  --text-model      使用 jiaodui-text 模型（可读文本报告）
  --model NAME      指定模型（jiaodui / jiaodui-text / jiaodui-json）
  --key KEY         显式指定 API key（默认读环境变量 / .env）
  --url URL         覆盖 API 端点
  -h, --help        显示本帮助

key 读取顺序：--key → $JIAODUI_API_KEY → 脚本目录向上查找 .env。
免费注册拿 key：https://jd.glowjames.top/register
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) SHOW_HELP=1; shift ;;
    -f|--file) FILE="${2:?缺少文件名}"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    --text-model) MODEL="jiaodui-text"; shift ;;
    --model) MODEL="${2:?缺少模型名}"; shift 2 ;;
    --key) KEY="${2:?缺少 key}"; shift 2 ;;
    --url) URL="${2:?缺少 URL}"; shift 2 ;;
    --) shift; while [ $# -gt 0 ]; do TEXT="$TEXT $1"; shift; done ;;
    -*) echo "$PROG: 未知参数 $1" >&2; usage >&2; exit 2 ;;
    *) TEXT="$TEXT $1"; shift ;;
  esac
done
TEXT="${TEXT# }"

if [ "$SHOW_HELP" = "1" ]; then usage; exit 0; fi

# ---- 输入：文件 > 参数 > stdin 管道 ----
if [ -n "$FILE" ]; then
  [ -r "$FILE" ] || { echo "$PROG: 文件不可读：$FILE" >&2; exit 2; }
  TEXT="$(cat -- "$FILE")"
elif [ -z "$TEXT" ] && [ ! -t 0 ]; then
  TEXT="$(cat)"
fi
[ -n "$TEXT" ] || { echo "$PROG: 没有输入文本" >&2; usage >&2; exit 2; }

# ---- key：参数 > 环境变量 > 向上查找 .env ----
if [ -z "$KEY" ]; then KEY="${JIAODUI_API_KEY:-}"; fi
if [ -z "$KEY" ]; then
  d="$(cd "$(dirname "$0")" && pwd)"
  while :; do
    if [ -f "$d/.env" ]; then
      v="$(grep -E '^JIAODUI_API_KEY=' "$d/.env" 2>/dev/null | tail -n 1 | cut -d= -f2-)"
      v="$(printf '%s' "$v" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
      if [ -n "$v" ]; then KEY="$v"; break; fi
    fi
    [ "$d" = "/" ] && break
    d="$(dirname "$d")"
  done
fi
if [ -z "$KEY" ]; then
  echo "$PROG: 未找到 JIAODUI_API_KEY。" >&2
  echo "请先免费注册拿 key（https://jd.glowjames.top/register），再设置环境变量：" >&2
  echo '  export JIAODUI_API_KEY="你的 key"' >&2
  echo "或本次显式传入：$PROG --key <key> \"文本\"" >&2
  exit 2
fi

command -v curl >/dev/null 2>&1 || { echo "$PROG: 需要 curl，请先安装。" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "$PROG: 需要 python3（仅用于 JSON 组装/解析），请先安装。" >&2; exit 1; }

# ---- 组装请求 ----
PAYLOAD="$(printf '%s' "$TEXT" | JIAODUI_MODEL="$MODEL" python3 -c \
  'import json,os,sys; print(json.dumps({"model": os.environ["JIAODUI_MODEL"], "messages": [{"role": "user", "content": sys.stdin.read()}], "stream": False}, ensure_ascii=False))')"

# ---- 发送 ----
HTTP_OUT="$(curl -sS --max-time 60 -X POST "$URL" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $KEY" \
  -H 'User-Agent: jiaodui.sh/1.0' \
  -d "$PAYLOAD" -w '\n%{http_code}')" || { echo "$PROG: 请求失败（网络错误）" >&2; exit 1; }
CODE="$(printf '%s' "$HTTP_OUT" | awk 'END{print}')"
BODY="$(printf '%s' "$HTTP_OUT" | sed '$d')"

case "$CODE" in
  200) ;;
  401) echo "$PROG: key 无效或已过期（HTTP 401）。请去个人中心重新生成：https://jd.glowjames.top/portal" >&2; exit 1 ;;
  429) echo "$PROG: 触发限流（每个 key 2 QPS），请稍后重试（HTTP 429）。" >&2; exit 1 ;;
  *) echo "$PROG: 请求失败（HTTP $CODE）：" >&2; printf '%s\n' "$BODY" | head -c 2000 >&2; echo >&2; exit 1 ;;
esac

# ---- 渲染 ----
printf '%s' "$BODY" | JIAODUI_JSON="$JSON_OUT" python3 -c '
import json, os, sys

try:
    resp = json.load(sys.stdin)
except Exception as e:
    print("解析响应失败：%s" % e, file=sys.stderr)
    sys.exit(1)

try:
    content = resp["choices"][0]["message"]["content"]
except (KeyError, IndexError, TypeError):
    print(json.dumps(resp, ensure_ascii=False, indent=2))
    sys.exit(1)

if os.environ.get("JIAODUI_JSON") == "1":
    try:
        print(json.dumps(json.loads(content), ensure_ascii=False, indent=2))
    except Exception:
        print(content)
    sys.exit(0)

try:
    r = json.loads(content)
except Exception:
    print(content)  # jiaodui-text 可读报告：原样输出
    sys.exit(0)

items = r.get("items", []) if isinstance(r, dict) else []
total = r.get("total", len(items)) if isinstance(r, dict) else 0
if not items:
    print("本次校对未发现差错。")
    sys.exit(0)

print("发现 %d 条：" % total)
for it in items:
    w = it.get("wrong") or it.get("c2") or ""
    s = it.get("suggestion") or it.get("c3") or ""
    print("  %s → %s" % (w, s))
'
