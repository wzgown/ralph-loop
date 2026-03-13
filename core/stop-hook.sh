#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Ralph Loop v3.4 - Stop Hook                                                 ║
# ║                                                                              ║
# ║  验证流程：                                                                   ║
# ║  1. 检查 AI 是否输出了 MISSION_COMPLETE                                       ║
# ║  2. 检查代码编译/语法                                                         ║
# ║  3. 运行当前功能的 verify_command                                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

RALPH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(dirname "$RALPH_DIR")"
CURRENT_DIR="$RALPH_DIR/current"
LOGS_DIR="$RALPH_DIR/logs"

FEATURES_FILE="$CURRENT_DIR/features.json"
RALPH_ITERATION="${RALPH_ITERATION:-$$}"
VERIFY_ERRORS_FILE="/tmp/ralph_verify_errors_${RALPH_ITERATION}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() {
    rm -f /tmp/ralph_verify_pass_$$ /tmp/ralph_verify_fail_$$
}
trap cleanup EXIT

echo "════════════════════════════════════════════════════════"
echo "  Stop Hook: 验证"
echo "════════════════════════════════════════════════════════"

# 1. 检查 MISSION_COMPLETE 信号
echo ""
echo -e "${BLUE}[1/3]${NC} 检查完成信号..."

# 找到最新的日志文件
LATEST_LOG=$(ls -t "$LOGS_DIR"/iteration_*.log 2>/dev/null | head -1)

if [ -z "$LATEST_LOG" ]; then
    echo -e "${RED}❌ 无日志文件${NC}"
    exit 1
fi

if grep -q "^MISSION_COMPLETE$" "$LATEST_LOG"; then
    echo -e "${GREEN}  ✅ MISSION_COMPLETE 信号已输出${NC}"
else
    echo -e "${RED}  ❌ 未找到 MISSION_COMPLETE 信号${NC}"
    echo ""
    echo "请确保在完成任务后单独一行输出："
    echo "  MISSION_COMPLETE"
    exit 1
fi

# 2. 检查代码状态（编译/语法）
echo ""
echo -e "${BLUE}[2/3]${NC} 检查代码状态..."

# 检测项目类型并运行相应的检查
if [ -f "$PROJECT_ROOT/Makefile" ] || [ -f "$PROJECT_ROOT/makefile" ]; then
    if grep -q "^build:" "$PROJECT_ROOT/Makefile" 2>/dev/null || \
       grep -q "^build:" "$PROJECT_ROOT/makefile" 2>/dev/null; then
        echo "  运行 make build..."
        cd "$PROJECT_ROOT"
        if make build > /tmp/ralph_build_$$ 2>&1; then
            echo -e "${GREEN}  ✅ make build 通过${NC}"
            rm -f /tmp/ralph_build_$$
        else
            echo -e "${RED}  ❌ make build 失败${NC}"
            cat /tmp/ralph_build_$$
            rm -f /tmp/ralph_build_$$
            exit 1
        fi
    fi
elif [ -f "$PROJECT_ROOT/package.json" ]; then
    echo "  检查 npm 项目..."
    cd "$PROJECT_ROOT"
    if npm run build > /tmp/ralph_build_$$ 2>&1 2>/dev/null; then
        echo -e "${GREEN}  ✅ npm build 通过${NC}"
        rm -f /tmp/ralph_build_$$
    else
        # build 脚本可能不存在，检查语法
        if [ -f "$PROJECT_ROOT/tsconfig.json" ]; then
            if npx tsc --noEmit > /tmp/ralph_build_$$ 2>&1; then
                echo -e "${GREEN}  ✅ TypeScript 检查通过${NC}"
            else
                echo -e "${RED}  ❌ TypeScript 检查失败${NC}"
                cat /tmp/ralph_build_$$
                rm -f /tmp/ralph_build_$$
                exit 1
            fi
        fi
        rm -f /tmp/ralph_build_$$
    fi
fi

# 3. 运行当前功能的 verify_command
echo ""
echo -e "${BLUE}[3/3]${NC} 运行验证命令..."

# 找到第一个未完成的功能
if [ -f "$FEATURES_FILE" ]; then
    # 使用 Python 解析 JSON（更可靠）
    VERIFY_CMD=$(python3 -c "
import json
with open('$FEATURES_FILE', 'r') as f:
    data = json.load(f)
features = data.get('features', data) if isinstance(data, dict) else data
for f in features:
    if not f.get('passes', False):
        cmd = f.get('verify_command', '')
        print(cmd)
        break
" 2>/dev/null)

    if [ -n "$VERIFY_CMD" ]; then
        echo "  执行: $VERIFY_CMD"
        cd "$PROJECT_ROOT"
        if eval "$VERIFY_CMD" > /tmp/ralph_verify_$$ 2>&1; then
            echo -e "${GREEN}  ✅ 验证命令通过${NC}"
            rm -f /tmp/ralph_verify_$$
        else
            EXIT_CODE=$?
            echo -e "${RED}  ❌ 验证命令失败 (exit: $EXIT_CODE)${NC}"
            echo ""
            echo "输出:"
            cat /tmp/ralph_verify_$$
            rm -f /tmp/ralph_verify_$$
            exit 1
        fi
    else
        echo -e "${YELLOW}  ⚠️  无 verify_command，跳过验证${NC}"
    fi
fi

# 全部通过
echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ 验证通过！${NC}"
echo "════════════════════════════════════════════════════════"

exit 0
