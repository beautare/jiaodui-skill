import argparse
import os
import platform
import sys

def main():
    parser = argparse.ArgumentParser(description="Configure JIAODUI_API_KEY environment variable")
    parser.add_argument("--key", help="The API key to set")
    args = parser.parse_args()

    key = args.key
    if not key:
        try:
            key = input("Enter your JIAODUI_API_KEY: ").strip()
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(1)

    if not key:
        print("Error: Key cannot be empty.", file=sys.stderr)
        sys.exit(1)

    try:
        # skill 根 = 向上找到的第一个含 SKILL.md 的目录（.env 写到那里）。
        # jiaodui-go 内是 .agents/skills/beautare-jiaodui/，独立 jiaodui-skill 仓是仓库根。
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = script_dir
        d = script_dir
        while True:
            if os.path.isfile(os.path.join(d, "SKILL.md")):
                project_root = d
                break
            parent = os.path.dirname(d)
            if parent == d:
                break
            d = parent
        env_path = os.path.join(project_root, ".env")

        lines = []
        if os.path.exists(env_path):
            try:
                with open(env_path, "r", encoding="utf-8-sig") as f:
                    lines = f.readlines()
            except UnicodeDecodeError:
                try:
                    with open(env_path, "r", encoding="utf-16") as f:
                        lines = f.readlines()
                except UnicodeDecodeError:
                    with open(env_path, "r", encoding="utf-8", errors="replace") as f:
                        lines = f.readlines()
        
        found = False
        for i, line in enumerate(lines):
            if line.strip().startswith("JIAODUI_API_KEY="):
                lines[i] = f"JIAODUI_API_KEY={key}\n"
                found = True
                break
        
        if not found:
            if lines and not lines[-1].endswith("\n"):
                lines[-1] += "\n"
            lines.append(f"JIAODUI_API_KEY={key}\n")
            
        with open(env_path, "w", encoding="utf-8") as f:
            f.writelines(lines)
        print(f"Successfully updated key in: {env_path}")
    except Exception as e:
        print(f"Warning: Failed to update .env file: {e}", file=sys.stderr)

    # 2. 打印持久化指引（不自动改 shell profile，由用户手动执行）。
    system = platform.system()
    if system == "Windows":
        print("如需当前 PowerShell 会话生效，请手动执行：")
        print(f'  $env:JIAODUI_API_KEY = "{key}"')
        print("如需永久生效，请手动设置用户环境变量 JIAODUI_API_KEY（设置 → 系统 → 高级系统设置 → 环境变量）。")
    elif system in ["Linux", "Darwin"]:
        shell = os.environ.get("SHELL", "")
        profile = ".bashrc"
        if "zsh" in shell:
            profile = ".zshrc"
        profile_path = os.path.expanduser(f"~/{profile}")
        print(f"如需当前 shell 生效：export JIAODUI_API_KEY=\"{key}\"")
        print(f"如需永久生效，请把上一行手动追加到 {profile_path} 后 source。")
    else:
        print(f"Unsupported OS: {system}. Please configure JIAODUI_API_KEY manually.", file=sys.stderr)

if __name__ == "__main__":
    main()
