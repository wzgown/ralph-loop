#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Ralph Loop v2.0 - 长时运行任务调度器                                          ║
# ║                                                                              ║
# ║  基于 Anthropic "Effective harnesses for long-running agents" 最佳实践        ║
# ║  核心设计：                                                                   ║
# ║  1. Initializer Agent - 首次运行设置环境                                      ║
# ║  2. Feature List (JSON) - 结构化功能清单，避免过早标记完成                       ║
# ║  3. Incremental Progress - 每次只做一个功能                                   ║
# ║  4. Progress File - 记录已完成的工作                                          ║
# ║  5. Clean State - 每次会话结束留下干净的 git 状态                               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -e

# ============================================================
# 配置
# ============================================================
RALPH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(dirname "$RALPH_DIR")"
SCRIPTS_DIR="$RALPH_DIR/scripts"
TEMPLATES_DIR="$RALPH_DIR/templates"
CURRENT_DIR="$RALPH_DIR/current"
QUEUE_DIR="$RALPH_DIR/queue"
TASKS_DIR="$RALPH_DIR/tasks"
LOGS_DIR="$RALPH_DIR/logs"

# 文件路径
CURRENT_TASK="$CURRENT_DIR/task.md"
CURRENT_FEATURES="$CURRENT_DIR/features.json"
CURRENT_PROGRESS="$CURRENT_DIR/progress.md"
CURRENT_INIT="$CURRENT_DIR/init.sh"
CURRENT_VERIFY="$CURRENT_DIR/verify.sh"
TASK_QUEUE="$QUEUE_DIR/task-queue.json"
STOP_HOOK="$SCRIPTS_DIR/stop-hook.sh"

# 模板
TASK_TEMPLATE="$TEMPLATES_DIR/task-template.md"
FEATURES_TEMPLATE="$TEMPLATES_DIR/features-template.json"
PROGRESS_TEMPLATE="$TEMPLATES_DIR/progress-template.md"
INIT_TEMPLATE="$TEMPLATES_DIR/init-template.sh"
VERIFY_TEMPLATE="$TEMPLATES_DIR/verify.sh"

# 参数
MAX_FEATURE_RETRIES=${MAX_FEATURE_RETRIES:-3}  # 单个功能最大重试次数
CLAUDE_TIMEOUT=${CLAUDE_TIMEOUT:-1800}  # 30分钟
DELAY_SECONDS=${DELAY_SECONDS:-2}
RALPH_AGENT=${RALPH_AGENT:-claude}  # 默认代理类型

# 代理执行指令目录
SKILLS_DIR="$RALPH_DIR/skills"

# 功能重试跟踪文件
FEATURE_RETRIES_FILE="$LOGS_DIR/feature_retries.json"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

mkdir -p "$CURRENT_DIR" "$QUEUE_DIR" "$TASKS_DIR" "$LOGS_DIR"

# ============================================================
# 获取代理执行指令文件
# ============================================================
get_executor_file() {
    local agent="$1"
    local executor_file="$SKILLS_DIR/executor-${agent}.md"

    if [ ! -f "$executor_file" ]; then
        log_err "未找到代理执行指令: $executor_file"
        log_info "可用代理: claude, codex, gemini"
        exit 1
    fi

    echo "$executor_file"
}

# 验证代理类型
validate_agent() {
    local agent="$1"
    case "$agent" in
        claude|codex|gemini)
            return 0
            ;;
        *)
            log_err "无效的代理类型: $agent"
            log_info "可用代理: claude, codex, gemini"
            exit 1
            ;;
    esac
}

# ============================================================
# 功能重试跟踪
# ============================================================
init_feature_retries() {
    if [ ! -f "$FEATURE_RETRIES_FILE" ]; then
        echo '{}' > "$FEATURE_RETRIES_FILE"
    fi
}

increment_feature_retry() {
    local feature_id="$1"
    init_feature_retries

    # 读取当前重试次数
    local current=$(grep -o "\"$feature_id\":[0-9]*" "$FEATURE_RETRIES_FILE" 2>/dev/null | cut -d: -f2 || echo "0")
    current=$((current + 1))

    # 更新文件（简单方式）
    local tmp_file=$(mktemp)
    if grep -q "\"$feature_id\"" "$FEATURE_RETRIES_FILE" 2>/dev/null; then
        sed "s/\"$feature_id\":[0-9]*/\"$feature_id\":$current/" "$FEATURE_RETRIES_FILE" > "$tmp_file"
    else
        # 添加新条目
        cat "$FEATURE_RETRIES_FILE" | sed "s/}/\"$feature_id\":$current}/" > "$tmp_file"
    fi
    mv "$tmp_file" "$FEATURE_RETRIES_FILE"

    echo "$current"
}

get_feature_retries() {
    local feature_id="$1"
    init_feature_retries
    grep -o "\"$feature_id\":[0-9]*" "$FEATURE_RETRIES_FILE" 2>/dev/null | cut -d: -f2 || echo "0"
}

should_skip_feature() {
    local feature_id="$1"
    local retries=$(get_feature_retries "$feature_id")
    [ "$retries" -ge "$MAX_FEATURE_RETRIES" ]
}

get_skipped_features() {
    init_feature_retries
    local skipped=""
    for fid in $(grep -o '"F[0-9]*"' "$CURRENT_FEATURES" 2>/dev/null | tr -d '"'); do
        if should_skip_feature "$fid"; then
            skipped="$skipped $fid"
        fi
    done
    echo "$skipped"
}

# ============================================================
# 日志函数
# ============================================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()     { echo -e "${RED}[ERR]${NC} $1"; }
log_ralph()   { echo -e "${MAGENTA}${BOLD}[RALPH]${NC} $1"; }
log_step()    { echo -e "${CYAN}  →${NC} $1"; }

# ============================================================
# JSON 工具函数 (无 jq 依赖)
# ============================================================
json_get() {
    local file="$1"
    local key="$2"
    grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null | \
        sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1
}

json_get_number() {
    local file="$1"
    local key="$2"
    grep -o "\"$key\"[[:space:]]*:[[:space:]]*[0-9]*" "$file" 2>/dev/null | \
        sed 's/.*:[[:space:]]*\([0-9]*\).*/\1/' | head -1
}

# ============================================================
# 帮助和状态
# ============================================================
show_help() {
    cat << 'EOF'
Ralph Loop v2.0 - 长时运行任务调度器

用法:
  ralph                          运行当前任务（增量模式）
  ralph --agent <type>           指定代理类型 (claude/codex/gemini)
  ralph --init                   初始化新任务（Initializer Agent 模式）
  ralph --queue                  显示任务队列
  ralph --enqueue <file>         添加任务到队列
  ralph --dequeue <id>           从队列移除任务
  ralph --next                   从队列获取下一个任务
  ralph --status                 显示当前状态
  ralph --features               显示功能清单
  ralph --progress               显示进度日志
  ralph --tasks                  列出所有任务
  ralph --archive [name]         归档当前任务
  ralph --reset                  重置当前任务
  ralph --clean                  清理工作区（确保干净状态）
  ralph --help                   显示帮助

代理类型:
  --agent claude    Claude Code (Anthropic) - 默认
  --agent codex     Codex CLI (OpenAI)
  --agent gemini    Gemini CLI (Google)

工作模式:
  1. Initializer Agent (--init): 设置环境，创建 features.json 和 init.sh
  2. Coding Agent (默认): 增量式工作，每次一个功能，保持干净状态

目录结构:
  .ralph/
  ├── scripts/          # 脚本
  ├── skills/           # 代理执行指令
  │   ├── executor-claude.md
  │   ├── executor-codex.md
  │   └── executor-gemini.md
  ├── templates/        # 模板
  ├── current/          # 当前任务
  │   ├── task.md       # 任务描述
  │   ├── features.json # 功能清单 (结构化)
  │   ├── progress.md   # 进度日志
  │   ├── init.sh       # 启动脚本
  │   └── verify.sh     # 验证脚本
  ├── queue/            # 任务队列
  │   └── task-queue.json
  ├── tasks/            # 历史任务归档
  └── logs/             # 循环日志

参数:
  MAX_ITERATIONS=10       最大循环次数
  MAX_FEATURE_RETRIES=3   单个功能最大重试次数
  CLAUDE_TIMEOUT=1800     单次执行超时(秒)
  RALPH_AGENT=claude      默认代理类型

EOF
}

show_status() {
    echo "════════════════════════════════════════════════════════"
    echo "  Ralph Loop v2.0 状态"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # 当前任务
    echo "📍 当前任务:"
    if [ -f "$CURRENT_TASK" ]; then
        local task_name=$(grep "^# 任务" "$CURRENT_TASK" | head -1 | sed 's/^# //')
        echo "   名称: ${task_name:-未命名}"
        echo "   文件: $CURRENT_TASK"

        # 功能统计
        if [ -f "$CURRENT_FEATURES" ]; then
            local total=$(grep -c '"id"' "$CURRENT_FEATURES" 2>/dev/null || echo "0")
            local passed=$(grep -c '"passes": true' "$CURRENT_FEATURES" 2>/dev/null || echo "0")
            echo "   功能: $passed/$total 通过"
        fi

        # Git 状态
        if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
            local git_status=$(git -C "$PROJECT_ROOT" status --short 2>/dev/null | wc -l | tr -d ' ')
            if [ "$git_status" -gt 0 ]; then
                echo "   Git: ⚠️  有 $git_status 个未提交的更改"
            else
                echo "   Git: ✅ 干净状态"
            fi
        fi
    else
        echo "   无当前任务"
    fi
    echo ""

    # 任务队列
    echo "📋 任务队列:"
    if [ -f "$TASK_QUEUE" ] && grep -q '"id"' "$TASK_QUEUE"; then
        local pending=$(grep -c '"status": "pending"' "$TASK_QUEUE" 2>/dev/null || echo "0")
        echo "   待处理: $pending 个任务"
    else
        echo "   队列为空"
    fi
}

show_features() {
    echo "════════════════════════════════════════════════════════"
    echo "  功能清单"
    echo "════════════════════════════════════════════════════════"

    if [ ! -f "$CURRENT_FEATURES" ]; then
        echo ""
        echo "无功能清单。运行 --init 创建。"
        return
    fi

    echo ""
    # 简单解析 JSON 中的功能列表
    grep -E '"(id|description|priority|passes)"' "$CURRENT_FEATURES" | \
        paste - - - - | \
        while read line; do
            local id=$(echo "$line" | grep -o '"id"[^,]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            local desc=$(echo "$line" | grep -o '"description"[^,]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            local passes=$(echo "$line" | grep -o '"passes"[^,}]*' | head -1 | sed 's/.*: *\(true\|false\).*/\1/')
            local status="⏳"
            [ "$passes" = "true" ] && status="✅"
            printf "  %s [%s] %s\n" "$status" "$id" "$desc"
        done
}

show_tasks() {
    echo "════════════════════════════════════════════════════════"
    echo "  任务列表"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # 当前任务
    if [ -f "$CURRENT_TASK" ]; then
        echo "📍 当前任务:"
        local task_title=$(grep "^# 任务" "$CURRENT_TASK" | head -1 | sed 's/^# //')
        local iter_count=$(grep -c "^## 第.*轮失败" "$CURRENT_TASK" 2>/dev/null || echo "0")
        echo "   名称: ${task_title:-未命名}"
        echo "   迭代: $iter_count 次"
        echo ""
    fi

    # 队列中的任务
    if [ -f "$TASK_QUEUE" ] && grep -q '"status": "pending"' "$TASK_QUEUE"; then
        echo "📋 待处理队列:"
        grep -A 3 '"status": "pending"' "$TASK_QUEUE" | grep '"name"' | \
            while read line; do
                local name=$(echo "$line" | sed 's/.*: *"\([^"]*\)".*/\1/')
                echo "   • $name"
            done
        echo ""
    fi

    # 历史任务
    if [ -d "$TASKS_DIR" ] && [ "$(ls -A $TASKS_DIR 2>/dev/null)" ]; then
        echo "📁 历史任务:"
        for task_dir in "$TASKS_DIR"/*; do
            if [ -d "$task_dir" ]; then
                local name=$(basename "$task_dir")
                local status=""
                if [ -f "$task_dir/SUMMARY.md" ]; then
                    status=$(grep "^- 状态:" "$task_dir/SUMMARY.md" | head -1 | sed 's/^- 状态: //')
                fi
                printf "   • %-50s %s\n" "$name" "${status:-已完成}"
            fi
        done
    fi
}

# ============================================================
# 任务队列管理
# ============================================================
enqueue_task() {
    local task_file="$1"

    if [ ! -f "$task_file" ]; then
        log_err "任务文件不存在: $task_file"
        exit 1
    fi

    local task_name=$(grep "^# 任务" "$task_file" | head -1 | sed 's/^# //' || echo "未命名任务")
    local task_id="T-$(date +%Y%m%d%H%M%S)"

    # 创建或更新队列文件
    if [ ! -f "$TASK_QUEUE" ]; then
        cat > "$TASK_QUEUE" << EOF
{
  "version": "1.0",
  "updated_at": "$(date -Iseconds)",
  "tasks": []
}
EOF
    fi

    # 追加任务（简单方式）
    local tmp_file=$(mktemp)
    awk -v id="$task_id" -v name="$task_name" -v file="$task_file" -v date="$(date -Iseconds)" '
    /^  \]/ {
        print "    ,{"
        print "      \"id\": \"" id "\","
        print "      \"name\": \"" name "\","
        print "      \"priority\": 5,"
        print "      \"status\": \"pending\","
        print "      \"task_file\": \"" file "\","
        print "      \"created_at\": \"" date "\","
        print "      \"started_at\": null,"
        print "      \"completed_at\": null"
        print "    }"
    }
    { print }
    ' "$TASK_QUEUE" > "$tmp_file"
    mv "$tmp_file" "$TASK_QUEUE"

    log_ok "已添加任务到队列: $task_name (ID: $task_id)"
}

dequeue_task() {
    local task_id="$1"

    if [ ! -f "$TASK_QUEUE" ]; then
        log_err "任务队列为空"
        exit 1
    fi

    # 标记为已移除（简单方式：直接注释或删除）
    local tmp_file=$(mktemp)
    awk -v id="$task_id" '
    /"id": *"'$task_id'"/ { skip=1 }
    skip && /^\s*}/ { skip=0; next }
    !skip { print }
    ' "$TASK_QUEUE" > "$tmp_file"
    mv "$tmp_file" "$TASK_QUEUE"

    log_ok "已从队列移除任务: $task_id"
}

get_next_task() {
    if [ ! -f "$TASK_QUEUE" ]; then
        return 1
    fi

    # 获取第一个 pending 任务
    local task_file=$(grep -B 5 '"status": "pending"' "$TASK_QUEUE" | \
        grep '"task_file"' | head -1 | \
        sed 's/.*: *"\([^"]*\)".*/\1/')

    if [ -z "$task_file" ] || [ ! -f "$task_file" ]; then
        return 1
    fi

    echo "$task_file"
    return 0
}

# ============================================================
# 任务初始化 (Initializer Agent 模式)
# ============================================================
init_task() {
    local task_file="${1:-$CURRENT_TASK}"

    if [ ! -f "$task_file" ]; then
        log_err "任务文件不存在: $task_file"
        log_info "创建新任务: $0 --new"
        exit 1
    fi

    log_ralph "════════════════════════════════════════════════════════"
    log_ralph "  Initializer Agent 模式"
    log_ralph "════════════════════════════════════════════════════════"
    echo ""

    # 如果有现有任务，先归档
    if [ -f "$CURRENT_TASK" ] && [ "$task_file" != "$CURRENT_TASK" ]; then
        log_info "归档现有任务..."
        auto_archive "0" "initializer"
    fi

    # 复制任务文件
    cp "$task_file" "$CURRENT_TASK"

    # 创建功能清单（如果不存在）
    if [ ! -f "$CURRENT_FEATURES" ]; then
        cp "$FEATURES_TEMPLATE" "$CURRENT_FEATURES"
        # 更新任务信息
        local task_name=$(grep "^# 任务" "$CURRENT_TASK" | head -1 | sed 's/^# //')
        local task_id="F-$(date +%Y%m%d%H%M%S)"
        sed -i '' "s/\"task_id\": \"\"/\"task_id\": \"$task_id\"/" "$CURRENT_FEATURES" 2>/dev/null || \
            sed -i "s/\"task_id\": \"\"/\"task_id\": \"$task_id\"/" "$CURRENT_FEATURES"
        sed -i '' "s/\"task_name\": \"\"/\"task_name\": \"$task_name\"/" "$CURRENT_FEATURES" 2>/dev/null || \
            sed -i "s/\"task_name\": \"\"/\"task_name\": \"$task_name\"/" "$CURRENT_FEATURES"
        sed -i '' "s/\"created_at\": \"\"/\"created_at\": \"$(date -Iseconds)\"/" "$CURRENT_FEATURES" 2>/dev/null || \
            sed -i "s/\"created_at\": \"\"/\"created_at\": \"$(date -Iseconds)\"/" "$CURRENT_FEATURES"
    fi

    # 创建进度文件
    if [ ! -f "$CURRENT_PROGRESS" ]; then
        cp "$PROGRESS_TEMPLATE" "$CURRENT_PROGRESS"
        local task_name=$(grep "^# 任务" "$CURRENT_TASK" | head -1 | sed 's/^# //')
        local task_id=$(json_get "$CURRENT_FEATURES" "task_id")
        sed -i '' "s/- \*\*任务ID\*\*:/- **任务ID**: $task_id/" "$CURRENT_PROGRESS" 2>/dev/null || \
            sed -i "s/- \*\*任务ID\*\*:/- **任务ID**: $task_id/" "$CURRENT_PROGRESS"
        sed -i '' "s/- \*\*任务名称\*\*:/- **任务名称**: $task_name/" "$CURRENT_PROGRESS" 2>/dev/null || \
            sed -i "s/- \*\*任务名称\*\*:/- **任务名称**: $task_name/" "$CURRENT_PROGRESS"
        sed -i '' "s/- \*\*开始时间\*\*:/- **开始时间**: $(date -Iseconds)/" "$CURRENT_PROGRESS" 2>/dev/null || \
            sed -i "s/- \*\*开始时间\*\*:/- **开始时间**: $(date -Iseconds)/" "$CURRENT_PROGRESS"
    fi

    # 创建启动脚本
    if [ ! -f "$CURRENT_INIT" ]; then
        cp "$INIT_TEMPLATE" "$CURRENT_INIT"
        chmod +x "$CURRENT_INIT"
    fi

    # 创建验证脚本
    if [ ! -f "$CURRENT_VERIFY" ]; then
        cp "$VERIFY_TEMPLATE" "$CURRENT_VERIFY"
        chmod +x "$CURRENT_VERIFY"
    fi

    log_ok "环境初始化完成:"
    echo ""
    echo "  📄 任务描述: $CURRENT_TASK"
    echo "  📋 功能清单: $CURRENT_FEATURES"
    echo "  📝 进度日志: $CURRENT_PROGRESS"
    echo "  🚀 启动脚本: $CURRENT_INIT"
    echo "  ✅ 验证脚本: $CURRENT_VERIFY"
    echo ""
    log_info "下一步:"
    echo "  1. 编辑 features.json 添加功能列表"
    echo "  2. 编辑 init.sh 设置环境启动命令"
    echo "  3. 编辑 verify.sh 添加验证逻辑"
    echo "  4. 运行: $0"
}

# ============================================================
# 构建上下文 Prompt (Coding Agent 模式)
# ============================================================
build_coding_prompt() {
    local iteration=$1
    local feature_id=$2

    # 获取执行指令文件
    local executor_file=$(get_executor_file "$RALPH_AGENT")
    local executor_content=""
    if [ -f "$executor_file" ]; then
        executor_content=$(cat "$executor_file")
    fi

    # 获取 git 状态
    local git_status=""
    local git_log=""
    if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        git_status=$(git -C "$PROJECT_ROOT" status --short 2>/dev/null || echo "无法获取")
        git_log=$(git -C "$PROJECT_ROOT" log --oneline -10 2>/dev/null || echo "")
    fi

    # 读取进度文件
    local progress_content=""
    if [ -f "$CURRENT_PROGRESS" ]; then
        progress_content=$(tail -50 "$CURRENT_PROGRESS")
    fi

    # 获取下一个待处理功能
    local next_feature=""
    if [ -f "$CURRENT_FEATURES" ]; then
        next_feature=$(grep -B 2 -A 8 '"passes": false' "$CURRENT_FEATURES" | head -15)
    fi

    # 获取跳过的功能
    local skipped_features=$(get_skipped_features)
    local skipped_info=""
    if [ -n "$skipped_features" ]; then
        skipped_info="## ⚠️ 已跳过的功能（达到最大重试次数）\n\n以下功能已跳过，**不要尝试实现**：\n$skipped_features\n\n---\n"
    fi

    cat << EOF
# Ralph Loop v2.0 - Coding Agent 模式 (代理: $RALPH_AGENT)

你是 Ralph Loop 的执行实例（循环 #$iteration）。

## 🎯 核心原则（必须遵守）

1. **增量工作**: 每次只完成 **一个功能**，不要尝试一次完成多个
2. **干净状态**: 完成后确保代码可提交（无语法错误、测试通过）
3. **结构化更新**: 只修改 features.json 中的 passes 字段
4. **端到端验证**: 使用浏览器自动化工具测试功能
5. **提交进度**: 完成后 git commit 并更新 progress.md

## 📁 项目信息

- 项目目录: \`$PROJECT_ROOT\`
- 任务文件: \`$CURRENT_TASK\`
- 功能清单: \`$CURRENT_FEATURES\`
- 进度日志: \`$CURRENT_PROGRESS\`
- 启动脚本: \`$CURRENT_INIT\`
- 验证脚本: \`$CURRENT_VERIFY\`

---

## 🤖 代理执行指令 ($RALPH_AGENT)

$executor_content

---

## 📋 当前任务

$(cat "$CURRENT_TASK")

---

## 🔧 Git 状态

\`\`\`
$git_status
\`\`\`

$([ -n "$git_log" ] && echo "### 最近提交" && echo "\`\`\`$git_log\`\`\`" || echo "")

---

## 📝 进度日志（最近）

$progress_content

---

## ⏭️ 下一个待处理功能

\`\`\`json
$next_feature
\`\`\`

$skipped_info
---

## 📋 工作流程（必须按顺序执行）

1. **获取上下文**
   \`\`\`bash
   pwd  # 确认工作目录
   git log --oneline -10  # 查看最近提交
   \`\`\`

2. **读取功能清单**
   - 阅读 \`$CURRENT_FEATURES\`
   - 选择第一个 \`passes: false\` 的功能

3. **验证基础功能**
   - 运行 \`init.sh\` 启动开发服务器
   - 使用浏览器自动化工具测试基本功能
   - 如果发现现有 bug，先修复

4. **实现单个功能**
   - 编写代码实现该功能
   - 运行测试验证
   - 使用浏览器自动化端到端测试

5. **更新状态**
   - 只修改 \`passes\` 字段为 \`true\`
   - **不要**删除或修改其他内容

6. **提交进度**
   \`\`\`bash
   git add -A
   git commit -m "feat: 完成功能 XXX"
   \`\`\`

7. **更新进度日志**
   - 在 \`progress.md\` 添加会话记录

8. **输出完成信号**
   完成后必须单独一行输出:
   \`\`\`
   MISSION_COMPLETE
   \`\`\`

## ⚠️ 禁止事项

- ❌ 不要一次实现多个功能
- ❌ 不要删除或修改 features.json 中的测试步骤
- ❌ 不要在未测试的情况下标记 passes: true
- ❌ 不要留下未提交的代码

EOF
}

# ============================================================
# 运行 Claude
# ============================================================
run_claude() {
    local context_prompt="$1"
    local log_file="$2"

    # 将 prompt 写入文件
    local prompt_id="ralph-$$-$(date +%s)"
    local prompt_file="$LOGS_DIR/${prompt_id}.txt"
    echo "$context_prompt" > "$prompt_file"

    log_info "Claude 已启动 (超时: ${CLAUDE_TIMEOUT}s)..."
    log_step "Prompt: $prompt_file"
    log_step "日志: $log_file"

    local start_time=$(date +%s)

    # macOS 兼容的超时实现
    env -u CLAUDECODE claude -p "$prompt_file" >> "$log_file" 2>&1 &
    local claude_pid=$!

    # 等待进程完成或超时
    local elapsed=0
    local completed=0
    while [ $elapsed -lt $CLAUDE_TIMEOUT ]; do
        if ! kill -0 $claude_pid 2>/dev/null; then
            completed=1
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))

        # 每30秒显示进度
        if [ $((elapsed % 30)) -eq 0 ]; then
            printf "\r${BLUE}[INFO]${NC} 运行中... %ds/%ds " "$elapsed" "$CLAUDE_TIMEOUT"
        fi
    done
    echo ""

    if [ $completed -eq 0 ]; then
        log_warn "执行超时，终止进程..."
        kill $claude_pid 2>/dev/null
        wait $claude_pid 2>/dev/null
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    wait $claude_pid 2>/dev/null
    local exit_code=$?

    if [ $completed -eq 1 ] && [ $exit_code -eq 0 ]; then
        log_ok "Claude 执行完成 (耗时: ${duration}s)"
    else
        log_warn "Claude 执行异常 (code: $exit_code, 耗时: ${duration}s)"
    fi

    # 清理旧的 prompt 文件
    find "$LOGS_DIR" -name "ralph-*.txt" -mtime +1 -delete 2>/dev/null

    return 0
}

# ============================================================
# 检查干净状态
# ============================================================
check_clean_state() {
    if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        local changes=$(git -C "$PROJECT_ROOT" status --short 2>/dev/null | wc -l | tr -d ' ')
        if [ "$changes" -gt 0 ]; then
            log_warn "工作区有 $changes 个未提交的更改"
            return 1
        fi
    fi
    return 0
}

# ============================================================
# 归档任务
# ============================================================
auto_archive() {
    local total_iterations="$1"
    local status="${2:-completed}"

    # 检查是否有任务文件
    if [ ! -f "$CURRENT_TASK" ]; then
        log_err "无当前任务可归档"
        exit 1
    fi

    # 提取任务名称（从 task.md 第一行标题）
    local task_name=$(grep "^# 任务" "$CURRENT_TASK" 2>/dev/null | head -1 | sed 's/^# 任务[：:]//' | tr -d '[:space:]')
    task_name="${task_name:-task-$(date +%Y%m%d-%H%M%S)}"

    local archive_name="$(date +%Y%m%d-%H%M%S)-${task_name}-iter${total_iterations}"
    local archive_dir="$TASKS_DIR/$archive_name"

    mkdir -p "$archive_dir"

    log_info "归档任务到: $archive_dir"

    # 复制所有当前任务文件
    local files_copied=0
    if [ -f "$CURRENT_TASK" ]; then
        cp "$CURRENT_TASK" "$archive_dir/task.md"
        log_step "task.md"
        files_copied=$((files_copied + 1))
    fi
    if [ -f "$CURRENT_FEATURES" ]; then
        cp "$CURRENT_FEATURES" "$archive_dir/features.json"
        log_step "features.json"
        files_copied=$((files_copied + 1))
    fi
    if [ -f "$CURRENT_PROGRESS" ]; then
        cp "$CURRENT_PROGRESS" "$archive_dir/progress.md"
        log_step "progress.md"
        files_copied=$((files_copied + 1))
    fi
    if [ -f "$CURRENT_INIT" ]; then
        cp "$CURRENT_INIT" "$archive_dir/init.sh"
        log_step "init.sh"
        files_copied=$((files_copied + 1))
    fi
    if [ -f "$CURRENT_VERIFY" ]; then
        cp "$CURRENT_VERIFY" "$archive_dir/verify.sh"
        log_step "verify.sh"
        files_copied=$((files_copied + 1))
    fi

    # 复制日志
    local logs_copied=0
    if [ -d "$LOGS_DIR" ]; then
        mkdir -p "$archive_dir/logs"

        # 复制 .log 文件
        for f in "$LOGS_DIR"/*.log; do
            if [ -f "$f" ]; then
                cp "$f" "$archive_dir/logs/"
                logs_copied=$((logs_copied + 1))
            fi
        done

        # 复制 .hook 文件
        for f in "$LOGS_DIR"/*.hook; do
            if [ -f "$f" ]; then
                cp "$f" "$archive_dir/logs/"
            fi
        done

        # 复制 ralph-*.txt prompt 文件
        for f in "$LOGS_DIR"/ralph-*.txt; do
            if [ -f "$f" ]; then
                cp "$f" "$archive_dir/logs/"
            fi
        done

        # 复制截图目录
        if [ -d "$LOGS_DIR/screenshots" ]; then
            cp -r "$LOGS_DIR/screenshots" "$archive_dir/logs/"
        fi

        log_step "logs/ ($logs_copied 个日志文件)"
    fi

    # 计算功能完成率
    local feature_stats=""
    if [ -f "$CURRENT_FEATURES" ]; then
        local total=$(grep -c '"id"' "$CURRENT_FEATURES" 2>/dev/null || echo "0")
        local passed=$(grep -c '"passes": true' "$CURRENT_FEATURES" 2>/dev/null || echo "0")
        feature_stats="- 功能: $passed/$total 通过"
    fi

    # 创建摘要
    cat > "$archive_dir/SUMMARY.md" << EOF
# 归档摘要

- 任务: $task_name
- 完成时间: $(date -Iseconds)
- 总循环次数: $total_iterations
- 状态: ✅ $status
$feature_stats

## 文件清单

- task.md - 任务描述
- features.json - 功能清单
- progress.md - 进度日志
- init.sh - 启动脚本
- verify.sh - 验证脚本
- logs/ - 循环日志 ($logs_copied 个文件)

EOF

    # 清理当前任务文件
    rm -f "$CURRENT_TASK" "$CURRENT_FEATURES" "$CURRENT_PROGRESS" "$CURRENT_INIT" "$CURRENT_VERIFY"

    # 清理日志目录（已归档）
    if [ -d "$LOGS_DIR" ]; then
        rm -f "$LOGS_DIR"/*.log "$LOGS_DIR"/*.hook "$LOGS_DIR"/ralph-*.txt 2>/dev/null || true
        rm -rf "$LOGS_DIR/screenshots" 2>/dev/null || true
        log_step "已清理日志目录"
    fi

    log_ok "📁 已归档: $archive_dir"
    log_info "文件: $files_copied 个, 日志: $logs_copied 个"
}

# ============================================================
# 主循环 (Coding Agent 模式)
# ============================================================
main() {
    # 检查是否有任务
    if [ ! -f "$CURRENT_TASK" ]; then
        # 尝试从队列获取下一个任务
        if get_next_task; then
            local next_task=$(get_next_task)
            log_info "从队列获取下一个任务: $next_task"
            init_task "$next_task"
        else
            log_err "无当前任务"
            log_info "创建新任务: $0 --init <task-file>"
            log_info "添加到队列: $0 --enqueue <task-file>"
            exit 1
        fi
    fi

    # 检查功能清单
    if [ ! -f "$CURRENT_FEATURES" ]; then
        log_warn "无功能清单，运行初始化..."
        init_task "$CURRENT_TASK"
    fi

    log_ralph "════════════════════════════════════════════════════════"
    log_ralph "  Ralph Loop v2.0 - Coding Agent 模式"
    log_ralph "════════════════════════════════════════════════════════"
    log_info "项目: $PROJECT_ROOT"
    log_info "任务: $CURRENT_TASK"
    log_info "熔断: 单个功能最多 $MAX_FEATURE_RETRIES 次重试"
    echo ""

    # 显示功能统计
    local total_features=$(grep -c '"id"' "$CURRENT_FEATURES" 2>/dev/null || echo "0")
    local passed_features=$(grep -c '"passes": true' "$CURRENT_FEATURES" 2>/dev/null || echo "0")
    log_info "功能进度: $passed_features/$total_features 通过"
    echo ""

    local iter=0

    while true; do
        iter=$((iter + 1))
        local log_file="$LOGS_DIR/iteration_$(printf '%03d' $iter).log"

        log_ralph "────────────────────────────────────────────────────"
        log_ralph "循环 #$iter"
        log_ralph "────────────────────────────────────────────────────"

        # 检查是否还有未完成的功能
        local remaining=$(grep -c '"passes": false' "$CURRENT_FEATURES" 2>/dev/null || echo "0")
        if [ "$remaining" -eq 0 ]; then
            log_ok "════════════════════════════════════════════════════════"
            log_ok "🎉 所有功能已完成！"
            log_ok "════════════════════════════════════════════════════════"

            auto_archive "$iter" "completed"
            exit 0
        fi

        # 检查是否所有未完成功能都被跳过
        local skipped=$(get_skipped_features)
        local skipped_count=$(echo "$skipped" | wc -w | tr -d ' ')
        if [ "$skipped_count" -ge "$remaining" ]; then
            log_warn "════════════════════════════════════════════════════════"
            log_warn "⚠️ 所有未完成功能已达到最大重试次数"
            log_warn "   跳过的功能:$skipped"
            log_warn "════════════════════════════════════════════════════════"

            auto_archive "$iter" "partial-skipped"
            exit 1
        fi

        # 构建 prompt
        local context_prompt=$(build_coding_prompt $iter)
        log_info "注入上下文..."
        echo "$context_prompt" | head -40
        echo ""
        log_info "... (完整内容见日志)"
        echo ""

        # 运行 Claude
        run_claude "$context_prompt" "$log_file"

        log_info "日志已保存: $log_file"

        # Stop Hook: 验证
        log_info "Stop Hook: 验证..."

        bash "$STOP_HOOK" 2>&1 | tee "${log_file}.hook"
        HOOK_EXIT_CODE=${PIPESTATUS[0]}

        if [ $HOOK_EXIT_CODE -eq 0 ]; then
            # 检查功能完成率
            local new_passed=$(grep -c '"passes": true' "$CURRENT_FEATURES" 2>/dev/null || echo "0")

            if [ "$new_passed" -gt "$passed_features" ]; then
                log_ok "════════════════════════════════════════════════════════"
                log_ok "✅ 功能完成！($passed_features → $new_passed)"
                log_ok "════════════════════════════════════════════════════════"

                passed_features=$new_passed

                # 更新进度日志
                cat >> "$CURRENT_PROGRESS" << EOF

---

## 会话 #$(date +%Y%m%d-%H%M%S)

- 时间: $(date -Iseconds)
- 循环: #$iter
- 状态: ✅ 功能完成
- 进度: $passed_features/$total_features

EOF
            else
                log_ok "验证通过，但无新功能完成"
            fi

            # 检查是否全部完成
            remaining=$(grep -c '"passes": false' "$CURRENT_FEATURES" 2>/dev/null || echo "0")
            if [ "$remaining" -eq 0 ]; then
                log_ok "════════════════════════════════════════════════════════"
                log_ok "🎉 所有功能已完成！任务结束"
                log_ok "════════════════════════════════════════════════════════"

                auto_archive "$iter" "completed"
                exit 0
            fi
        else
            # 失败：增加当前功能的重试计数
            local current_feature=$(grep -m1 '"passes": false' "$CURRENT_FEATURES" 2>/dev/null | grep -o '"id"[^,]*' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

            if [ -n "$current_feature" ]; then
                local retries=$(increment_feature_retry "$current_feature")
                log_warn "功能 $current_feature 重试次数: $retries/$MAX_FEATURE_RETRIES"

                if [ "$retries" -ge "$MAX_FEATURE_RETRIES" ]; then
                    log_err "功能 $current_feature 已达到最大重试次数，将被跳过"
                fi
            fi

            # 失败：追加日志
            log_warn "标准未达成，更新任务文件..."

            cat >> "$CURRENT_TASK" << EOF

---

## 第 $iter 轮失败

\`\`\`
$(cat "${log_file}.hook" | head -30)
\`\`\`

**要求**: 修复上述错误后重新运行。

EOF

            # 更新进度日志
            cat >> "$CURRENT_PROGRESS" << EOF

---

## 会话 #$(date +%Y%m%d-%H%M%S)

- 时间: $(date -Iseconds)
- 循环: #$iter
- 状态: ❌ 验证失败
- 进度: $passed_features/$total_features
- 错误: $(cat "${log_file}.hook" | head -5)

EOF

            log_info "已追加失败日志"
        fi

        sleep $DELAY_SECONDS
    done
}

# ============================================================
# 命令处理
# ============================================================
case "${1:-}" in
    --agent|-a)
        validate_agent "$2"
        RALPH_AGENT="$2"
        log_ok "代理类型设置为: $RALPH_AGENT"
        # 如果有第三个参数，继续处理
        if [ -n "${3:-}" ]; then
            shift 2
            set -- "$@"
        else
            # 只设置代理，不运行任务
            exit 0
        fi
        # 继续执行后续命令
        case "${1:-}" in
            "")
                main
                ;;
            *)
                exec "$0" "$@"
                ;;
        esac
        ;;
    --init|-i)
        init_task "$2"
        ;;
    --queue|-q)
        cat "$TASK_QUEUE" 2>/dev/null || echo "队列为空"
        ;;
    --enqueue|-e)
        enqueue_task "$2"
        ;;
    --dequeue|-d)
        dequeue_task "$2"
        ;;
    --next|-n)
        if get_next_task; then
            echo "下一个任务: $(get_next_task)"
        else
            echo "队列为空"
        fi
        ;;
    --status|-s)
        show_status
        ;;
    --features|-f)
        show_features
        ;;
    --progress|-p)
        cat "$CURRENT_PROGRESS" 2>/dev/null || echo "无进度日志"
        ;;
    --tasks|-l)
        show_tasks
        ;;
    --archive|-a)
        auto_archive "0" "${2:-manual}"
        ;;
    --reset|-r)
        if [ -f "$CURRENT_TASK" ]; then
            sed -i '' '/^## 失败日志/,$d' "$CURRENT_TASK" 2>/dev/null || \
                sed -i '/^## 失败日志/,$d' "$CURRENT_TASK"
            cat >> "$CURRENT_TASK" << 'EOF'

## 失败日志

<!-- 每轮失败后自动追加 -->
EOF
            log_ok "已重置失败日志"
        else
            log_err "无当前任务"
        fi
        ;;
    --clean|-c)
        if check_clean_state; then
            log_ok "工作区状态干净"
        else
            log_warn "请先提交或清理更改"
            git -C "$PROJECT_ROOT" status --short
        fi
        ;;
    --new)
        if [ -f "$CURRENT_TASK" ]; then
            log_info "归档现有任务..."
            auto_archive "0" "new-task"
        fi
        cp "$TASK_TEMPLATE" "$CURRENT_TASK"
        log_ok "已创建新任务: $CURRENT_TASK"
        log_info "编辑任务后运行: $0 --init"
        ;;
    --help|-h)
        show_help
        ;;
    "")
        main
        ;;
    *)
        log_err "未知参数: $1"
        show_help
        exit 1
        ;;
esac
