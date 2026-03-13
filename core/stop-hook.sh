#!/bin/bash

# Ralph Loop v3.4 - Stop Hook
#
# 验证流程：
# 1. 检查 AI 是否输出了 MISSION_COMPLETE
# 2. 检查代码编译/语法
# 3. 运行当前功能的 verify_command

RALPH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(dirname "$RALPH_DIR")"
CURRENT_DIR="$RALPH_DIR/current"
LOGS_DIR="$RALPH_DIR/logs"

FEATURES_FILE="$CURRENT_DIR/features.json"
RALPH_ITERATION="${RALPH_ITERATION:-$$}"

cleanup() {
    rm -f /tmp/ralph_build_$$ /tmp/ralph_verify_$$
}
trap cleanup EXIT

echo "════════════════════════════════════════════════════════"
echo "  Stop Hook: 验证"
echo "════════════════════════════════════════════════════════"

# 1. 检查 MISSION_COMPLETE 信号
echo ""
echo "[1/3] 检查完成信号..."

LATEST_LOG=$(ls -t "$LOGS_DIR"/iteration_*.log 2>/dev/null | head -1)

if [ -z "$LATEST_LOG" ]; then
    echo "  ✗ 无日志文件"
    exit 1
fi

if grep -q "^MISSION_COMPLETE$" "$LATEST_LOG"; then
    echo "  ✓ MISSION_COMPLETE 信号已输出"
else
    echo "  ✗ 未找到 MISSION_COMPLETE 信号"
    echo ""
    echo "请确保在完成任务后单独一行输出："
    echo "  MISSION_COMPLETE"
    exit 1
fi

# 2. 检查代码状态
echo ""
echo "[2/3] 检查代码状态..."

if [ -f "$PROJECT_ROOT/Makefile" ]; then
    if grep -q "^build:" "$PROJECT_ROOT/Makefile" 2>/dev/null; then
        echo "  运行 make build..."
        cd "$PROJECT_ROOT"
        if make build > /tmp/ralph_build_$$ 2>&1; then
            echo "  ✓ make build 通过"
        else
            echo "  ✗ make build 失败"
            cat /tmp/ralph_build_$$
            exit 1
        fi
    fi
elif [ -f "$PROJECT_ROOT/package.json" ]; then
    cd "$PROJECT_ROOT"
    if [ -f "$PROJECT_ROOT/tsconfig.json" ]; then
        echo "  运行 TypeScript 检查..."
        if npx tsc --noEmit > /tmp/ralph_build_$$ 2>&1; then
            echo "  ✓ TypeScript 检查通过"
        else
            echo "  ✗ TypeScript 检查失败"
            cat /tmp/ralph_build_$$
            exit 1
        fi
    fi
fi

# 3. 运行 verify_command
echo ""
echo "[3/3] 运行验证命令..."

if [ -f "$FEATURES_FILE" ]; then
    VERIFY_CMD=$(python3 -c "
import json
with open('$FEATURES_FILE', 'r') as f:
    data = json.load(f)
features = data.get('features', data) if isinstance(data, dict) else data
for f in features:
    if not f.get('passes', False):
        print(f.get('verify_command', ''))
        break
" 2>/dev/null)

    if [ -n "$VERIFY_CMD" ]; then
        echo "  执行: $VERIFY_CMD"
        cd "$PROJECT_ROOT"
        if eval "$VERIFY_CMD" > /tmp/ralph_verify_$$ 2>&1; then
            echo "  ✓ 验证命令通过"
        else
            echo "  ✗ 验证命令失败 (exit: $?)"
            echo ""
            echo "输出:"
            cat /tmp/ralph_verify_$$
            exit 1
        fi
    else
        echo "  - 无 verify_command，跳过"
    fi
fi

# 全部通过
echo ""
echo "════════════════════════════════════════════════════════"
echo "✓ 验证通过"
echo "════════════════════════════════════════════════════════"

exit 0
