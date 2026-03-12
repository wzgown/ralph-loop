#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Ralph Loop v3.1 - Stop Hook                                                 ║
# ║                                                                              ║
# ║  验证流程：                                                                   ║
# ║  1. 检查 AI 是否输出了 MISSION_COMPLETE                                       ║
# ║  2. 检查 Git 工作区状态（可选）                                                ║
# ║  3. 执行 features.json 中每个 passes:true 功能的 verify_command               ║
# ║  4. 失败时将错误详情写入临时文件，供 ralph.py 记录到 progress.md               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

RALPH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(dirname "$RALPH_DIR")"
CURRENT_DIR="$RALPH_DIR/current"
LOGS_DIR="$RALPH_DIR/logs"

FEATURES_FILE="$CURRENT_DIR/features.json"

# 从环境变量获取 iteration，用于错误文件命名
RALPH_ITERATION="${RALPH_ITERATION:-$$}"
VERIFY_ERRORS_FILE="/tmp/ralph_verify_errors_${RALPH_ITERATION}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 清理函数
cleanup() {
    rm -f /tmp/ralph_verify_pass_$$ /tmp/ralph_verify_fail_$$
    # 注意：不删除 VERIFY_ERRORS_FILE，ralph.py 需要读取
}
trap cleanup EXIT

echo "════════════════════════════════════════════════════════"
echo "  Stop Hook: 验证"
echo "════════════════════════════════════════════════════════"

# ============================================================
# 步骤 1：检查 AI 是否声称完成
# ============================================================
echo ""
echo -e "${BLUE}[1/3]${NC} 检查完成信号..."

LATEST_LOG=$(ls -t "$LOGS_DIR"/iteration_*.log 2>/dev/null | head -1)
if [ -z "$LATEST_LOG" ]; then
    echo -e "${RED}❌ 无日志文件${NC}"
    exit 1
fi

if ! grep -q "MISSION_COMPLETE" "$LATEST_LOG"; then
    echo -e "${RED}❌ AI 未输出 MISSION_COMPLETE 信号${NC}"
    echo "   AI 需要在完成任务后输出 MISSION_COMPLETE"
    exit 1
fi
echo -e "${GREEN}✅ AI 已声称完成 (MISSION_COMPLETE)${NC}"

# ============================================================
# 步骤 2：检查 Git 状态（可选但推荐）
# ============================================================
echo ""
echo -e "${BLUE}[2/3]${NC} 检查工作区状态..."

if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    CHANGES=$(git -C "$PROJECT_ROOT" status --short 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CHANGES" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  工作区有 $CHANGES 个未提交的更改${NC}"
        echo ""
        git -C "$PROJECT_ROOT" status --short | head -10
        echo ""
        echo -e "${YELLOW}建议: AI 应该提交这些更改以保持干净状态${NC}"
        # 不阻止验证，只是警告
    else
        echo -e "${GREEN}✅ 工作区状态干净${NC}"
    fi
else
    echo "   (非 Git 仓库，跳过)"
fi

# ============================================================
# 步骤 3：执行功能验证 (verify_command)
# ============================================================
echo ""
echo -e "${BLUE}[3/3]${NC} 执行功能验证..."

if [ ! -f "$FEATURES_FILE" ]; then
    echo -e "${RED}❌ 功能清单不存在: $FEATURES_FILE${NC}"
    exit 1
fi

# 初始化错误文件
echo "" > "$VERIFY_ERRORS_FILE"

# 临时文件记录统计
rm -f /tmp/ralph_verify_pass_$$ /tmp/ralph_verify_fail_$$

echo ""
echo "正在验证 passes:true 的功能..."

# 将 JSON 压缩，用换行分隔每个功能块 (macOS 兼容)
# 匹配 }, 或 } 后面跟着空白和 { 或 ]
cat "$FEATURES_FILE" | tr '\n' ' ' | sed -e 's/} *,/}\'$'\n/g' -e 's/} *{/}\'$'\n{ /g' | while read -r block; do
    # 只处理 passes: true 的功能
    if echo "$block" | grep -q '"passes"[[:space:]]*:[[:space:]]*true'; then
        # 提取 id
        FID=$(echo "$block" | grep -oE '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
        # 提取 description
        FDESC=$(echo "$block" | grep -oE '"description"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"\([^"]*\)".*/\1/' | cut -c1-50)
        # 提取 verify_command
        VCMD=$(echo "$block" | grep -oE '"verify_command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"\([^"]*\)".*/\1/')

        # 跳过空的或占位符命令
        if [ -z "$VCMD" ] || [ "$VCMD" = "TODO: 添加验证命令" ] || [ "$VCMD" = "echo 'TODO: 添加验证命令'" ]; then
            echo -e "  ${YELLOW}⏭${NC} [$FID] 跳过 (无验证命令)"
            continue
        fi

        echo ""
        echo "  验证 [$FID]: $FDESC..."
        echo "    命令: $VCMD"

        # 临时文件存储命令输出
        CMD_OUTPUT="/tmp/ralph_cmd_output_$$"
        # 执行验证命令，捕获输出
        if eval "$VCMD" > "$CMD_OUTPUT" 2>&1; then
            echo -e "    ${GREEN}✅ 通过${NC}"
            echo "pass" >> /tmp/ralph_verify_pass_$$
        else
            EXIT_CODE=$?
            echo -e "    ${RED}❌ 失败 (退出码: $EXIT_CODE)${NC}"

            # 读取错误输出（限制行数）
            ERROR_OUTPUT=$(head -50 "$CMD_OUTPUT")

            # 显示错误摘要
            echo -e "    ${RED}错误输出:${NC}"
            echo "$ERROR_OUTPUT" | head -10 | sed 's/^/      /'

            # 记录到错误文件
            {
                echo "## 功能 [$FID]: $FDESC"
                echo ""
                echo "**命令**: \`$VCMD\`"
                echo "**退出码**: $EXIT_CODE"
                echo ""
                echo "**错误输出**:"
                printf '```\n'
                echo "$ERROR_OUTPUT"
                printf '```\n'
                echo ""
            } >> "$VERIFY_ERRORS_FILE"

            echo "fail" >> /tmp/ralph_verify_fail_$$
        fi
        rm -f "$CMD_OUTPUT"
    fi
done

# 统计结果
PASS_COUNT=$([ -f /tmp/ralph_verify_pass_$$ ] && wc -l < /tmp/ralph_verify_pass_$$ || echo "0")
FAIL_COUNT=$([ -f /tmp/ralph_verify_fail_$$ ] && wc -l < /tmp/ralph_verify_fail_$$ || echo "0")

echo ""
echo "════════════════════════════════════════════════════════"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "${RED}❌ 验证失败: $FAIL_COUNT 个功能未通过验证${NC}"
    echo ""
    echo "功能进度: $PASS_COUNT 通过, $FAIL_COUNT 失败"
    echo ""
    echo "📄 错误详情已保存，将记录到 progress.md"
    echo "════════════════════════════════════════════════════════"

    # 输出错误文件路径供 ralph.py 读取
    echo "VERIFY_ERRORS_FILE=$VERIFY_ERRORS_FILE" > /tmp/ralph_verify_result_$$

    exit 1
else
    echo -e "${GREEN}✅ 验证通过！${NC}"

    # 显示功能进度
    TOTAL=$(grep -c '"id"' "$FEATURES_FILE" 2>/dev/null || echo "0")
    PASSED=$(grep -c '"passes": true' "$FEATURES_FILE" 2>/dev/null || echo "0")
    echo ""
    echo "📊 功能进度: $PASSED/$TOTAL 通过"

    echo "════════════════════════════════════════════════════════"

    # 清理错误文件
    rm -f "$VERIFY_ERRORS_FILE"

    exit 0
fi
