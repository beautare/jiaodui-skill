import argparse
import json
import os
import sys
from typing import Optional
import urllib.error
import urllib.request

def find_skill_root() -> str:
    # skill 根 = 向上找到的第一个含 SKILL.md 的目录。
    # jiaodui-go 内是 .agents/skills/beautare-jiaodui/，独立 jiaodui-skill 仓是仓库根。
    # .env 写到 skill 根（subtree 同步两边通用）。
    d = os.path.dirname(os.path.abspath(__file__))
    while True:
        if os.path.isfile(os.path.join(d, "SKILL.md")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return os.path.dirname(os.path.abspath(__file__))
        d = parent


def load_api_key(passed_key: Optional[str]) -> Optional[str]:
    if passed_key:
        return passed_key
    # skill 根目录的 .env 优先
    env_path = os.path.join(find_skill_root(), ".env")
    if os.path.exists(env_path):
        try:
            with open(env_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("JIAODUI_API_KEY="):
                        val = line.split("=", 1)[1].strip().strip('"').strip("'")
                        if val:
                            return val
        except Exception:
            pass
    # Fallback to system/process environment variable
    return os.environ.get("JIAODUI_API_KEY")

def main():
    parser = argparse.ArgumentParser(description="Test jiaodui-go OpenAI-compatible Completions API")
    parser.add_argument("--key", help="API key (defaults to JIAODUI_API_KEY env var or .env file)")
    parser.add_argument("--text", default="小伙伴们看来放假的时间，我们还要在等等了。", help="Text to proofread")
    parser.add_argument("--model", default="jiaodui", choices=["jiaodui", "jiaodui-text", "jiaodui-json"], help="Model name")
    parser.add_argument("--stream", action="store_true", help="Enable SSE streaming")
    parser.add_argument("--url", default="https://jd.glowjames.top/v1/chat/completions", help="API Endpoint URL")
    
    args = parser.parse_args()
    
    api_key = load_api_key(args.key)
    if not api_key:
        print("Error: API Key is required. Set JIAODUI_API_KEY env var, create .env file, or pass via --key", file=sys.stderr)
        sys.exit(1)
        
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
        "User-Agent": "jiaodui-skill-client/1.0"
    }
    
    payload = {
        "model": args.model,
        "messages": [{"role": "user", "content": args.text}],
        "stream": args.stream
    }
    
    # Reconfigure stdout to UTF-8
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        
    print(f"Connecting to: {args.url}")
    print(f"Model: {args.model}, Stream: {args.stream}")
    print(f"Input: {args.text}\n")
    
    try:
        req = urllib.request.Request(
            args.url,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST"
        )
        with urllib.request.urlopen(req) as f:
            if args.stream:
                for line_bytes in f:
                    line = line_bytes.decode("utf-8").strip()
                    if line:
                        print(line)
            else:
                resp_body = f.read().decode("utf-8")
                try:
                    parsed = json.loads(resp_body)
                    print(json.dumps(parsed, indent=2, ensure_ascii=False))
                except Exception:
                    print(resp_body)
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
        try:
            err_body = e.read().decode("utf-8")
            try:
                parsed = json.loads(err_body)
                print(json.dumps(parsed, indent=2, ensure_ascii=False), file=sys.stderr)
            except Exception:
                print(err_body, file=sys.stderr)
        except Exception:
            pass
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
