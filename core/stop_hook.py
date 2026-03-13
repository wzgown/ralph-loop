#!/usr/bin/env python3
"""
Ralph Loop v3.4 - Stop Hook

验证流程：
1. 检查 AI 是否输出了 MISSION_COMPLETE
2. 检查代码编译/语法
3. 运行当前功能的 verify_command

环境变量（由 ralph.py 传入）：
- RALPH_DATA_DIR: 项目数据目录 (.ralph/)
- RALPH_PROJECT_ROOT: 项目根目录
- RALPH_ITERATION: 当前迭代 ID
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def get_env(key: str) -> str:
    """获取必需的环境变量"""
    value = os.environ.get(key)
    if not value:
        print(f"错误: {key} 未设置", file=sys.stderr)
        sys.exit(1)
    return value


def check_mission_complete(logs_dir: Path) -> bool:
    """检查 MISSION_COMPLETE 信号"""
    print("[1/3] 检查完成信号...")

    # 找最新的日志文件
    log_files = sorted(
        logs_dir.glob("iteration_*.log"),
        key=lambda p: p.stat().st_mtime if p.exists() else 0,
        reverse=True
    )

    if not log_files:
        print("  ✗ 无日志文件")
        return False

    latest_log = log_files[0]
    content = latest_log.read_text(encoding='utf-8')

    if "MISSION_COMPLETE" in content.split('\n'):
        print("  ✓ MISSION_COMPLETE 信号已输出")
        return True
    else:
        print("  ✗ 未找到 MISSION_COMPLETE 信号")
        print()
        print("请确保在完成任务后单独一行输出：")
        print("  MISSION_COMPLETE")
        return False


def check_code_status(project_root: Path) -> bool:
    """检查代码状态（编译/语法）"""
    print("[2/3] 检查代码状态...")

    makefile = project_root / "Makefile"
    package_json = project_root / "package.json"
    tsconfig = project_root / "tsconfig.json"

    if makefile.exists():
        # 检查是否有 build target
        content = makefile.read_text(encoding='utf-8')
        if content.startswith("build:") or "\nbuild:" in content:
            print("  运行 make build...")
            result = subprocess.run(
                ["make", "build"],
                cwd=project_root,
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                print("  ✓ make build 通过")
                return True
            else:
                print("  ✗ make build 失败")
                print(result.stdout)
                print(result.stderr)
                return False

    if package_json.exists() and tsconfig.exists():
        print("  运行 TypeScript 检查...")
        result = subprocess.run(
            ["npx", "tsc", "--noEmit"],
            cwd=project_root,
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print("  ✓ TypeScript 检查通过")
            return True
        else:
            print("  ✗ TypeScript 检查失败")
            print(result.stdout)
            print(result.stderr)
            return False

    print("  - 无构建检查，跳过")
    return True


def get_verify_command(features_file: Path) -> str | None:
    """获取当前功能的 verify_command"""
    if not features_file.exists():
        return None

    with open(features_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    features = data.get('features', data) if isinstance(data, dict) else data

    for feature in features:
        if not feature.get('passes', False):
            return feature.get('verify_command', '')

    return None


def run_verify_command(project_root: Path, features_file: Path) -> bool:
    """运行验证命令"""
    print("[3/3] 运行验证命令...")

    verify_cmd = get_verify_command(features_file)

    if not verify_cmd:
        print("  - 无 verify_command，跳过")
        return True

    print(f"  执行: {verify_cmd}")
    result = subprocess.run(
        verify_cmd,
        shell=True,
        cwd=project_root,
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        print("  ✓ 验证命令通过")
        return True
    else:
        print(f"  ✗ 验证命令失败 (exit: {result.returncode})")
        print()
        print("输出:")
        print(result.stdout)
        print(result.stderr)
        return False


def main():
    # 获取环境变量
    data_dir = Path(get_env("RALPH_DATA_DIR"))
    project_root = Path(get_env("RALPH_PROJECT_ROOT"))

    current_dir = data_dir / "current"
    logs_dir = data_dir / "logs"
    features_file = current_dir / "features.json"

    print("════════════════════════════════════════════════════════")
    print("  Stop Hook: 验证")
    print("════════════════════════════════════════════════════════")
    print()

    # 1. 检查 MISSION_COMPLETE
    if not check_mission_complete(logs_dir):
        sys.exit(1)

    print()

    # 2. 检查代码状态
    if not check_code_status(project_root):
        sys.exit(1)

    print()

    # 3. 运行验证命令
    if not run_verify_command(project_root, features_file):
        sys.exit(1)

    # 全部通过
    print()
    print("════════════════════════════════════════════════════════")
    print("✓ 验证通过")
    print("════════════════════════════════════════════════════════")

    sys.exit(0)


if __name__ == "__main__":
    main()
