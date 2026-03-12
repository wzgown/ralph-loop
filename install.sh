#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Ralph Loop - 安装脚本 v3.2                                                  ║
# ║                                                                              ║
# ║  架构设计:                                                                    ║
# ║  - 全局 Skill: ~/.claude/skills/ralph-loop/ (脚本、模板、参考文档)             ║
# ║  - 项目数据: .ralph/ (任务、队列、日志)                                        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -e

# 颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_RALPH_DIR=".ralph"
AGENT_TYPE=""
SKIP_SCAFFOLD=false
SKIP_SKILL=false

# 检测安装模式：本地安装还是远程安装
REMOTE_REPO="https://raw.githubusercontent.com/wzgown/ralph-loop/main"
if [ ! -d "$SCRIPT_DIR/core" ]; then
    INSTALL_MODE="remote"
else
    INSTALL_MODE="local"
fi

# 从远程或本地获取文件
fetch_file() {
    local src_path="$1"
    local dest_path="$2"

    # 确保目标目录存在
    mkdir -p "$(dirname "$dest_path")"

    if [ "$INSTALL_MODE" = "remote" ]; then
        if ! curl -fsSL "$REMOTE_REPO/$src_path" -o "$dest_path" 2>/dev/null; then
            echo -e "${RED}  ❌ 下载失败: $src_path${NC}"
            return 1
        fi
    else
        if [ -f "$SCRIPT_DIR/$src_path" ]; then
            cp "$SCRIPT_DIR/$src_path" "$dest_path"
        else
            echo -e "${RED}  ❌ 文件不存在: $src_path${NC}"
            return 1
        fi
    fi
}

# 从远程或本地获取目录
fetch_dir() {
    local src_path="$1"
    local dest_path="$2"
    local files="$3"

    mkdir -p "$dest_path"

    if [ "$INSTALL_MODE" = "remote" ]; then
        # 使用提供的文件列表
        for f in $files; do
            curl -fsSL "$REMOTE_REPO/$src_path/$f" -o "$dest_path/$f" 2>/dev/null || true
        done
    else
        if [ -d "$SCRIPT_DIR/$src_path" ]; then
            cp -r "$SCRIPT_DIR/$src_path/"* "$dest_path/" 2>/dev/null || true
        fi
    fi
}

# 自动检测 agent 类型
detect_agent() {
    # 优先级 1: 环境变量
    if [ -n "${RALPH_AGENT:-}" ]; then
        echo "$RALPH_AGENT"
        return 0
    fi

    # 优先级 2: Claude Code 标记
    if [ -n "${CLAUDE_CODE_SESSION:-}" ] || [ -f ".claude/CLAUDE.md" ] || [ -n "${CLAUDE_PROJECT:-}" ]; then
        echo "claude"
        return 0
    fi

    # 优先级 3: Codex CLI 标记
    if [ -n "${CODEX_SESSION:-}" ] || [ -f ".codexrc" ]; then
        echo "codex"
        return 0
    fi

    # 优先级 4: Gemini CLI 标记
    if [ -n "${GEMINI_SESSION:-}" ] || [ -f ".geminirc" ]; then
        echo "gemini"
        return 0
    fi

    # 优先级 5: OpenClaw 标记
    if [ -n "${OPENCLAW_SESSION:-}" ] || [ -f ".openclawrc" ]; then
        echo "openclaw"
        return 0
    fi

    # 默认
    echo "claude"
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --agent, -a <type>   指定代理类型 (claude/codex/gemini/openclaw)"
    echo "  --detect, -d         自动检测代理类型"
    echo "  --skill-only         只安装全局 Skill，不创建项目脚手架"
    echo "  --scaffold-only      只创建项目脚手架，不安装全局 Skill"
    echo "  --help, -h           显示帮助"
    echo ""
    echo "架构说明:"
    echo "  全局 Skill: ~/.claude/skills/ralph-loop/ (脚本、模板、参考文档)"
    echo "  项目数据:   .ralph/ (任务、队列、日志)"
    echo ""
    echo "支持的代理:"
    echo "  claude    - Claude Code (Anthropic)"
    echo "  codex     - Codex CLI (OpenAI)"
    echo "  gemini    - Gemini CLI (Google)"
    echo "  openclaw  - OpenClaw"
    echo ""
    echo "示例:"
    echo "  $0 --agent claude       完整安装"
    echo "  $0 --skill-only         只更新全局 Skill"
    echo "  $0 --scaffold-only      只创建项目脚手架"
    echo ""
    echo "远程安装:"
    echo "  curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash -s -- --agent claude"
    exit 0
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --agent|-a)
            AGENT_TYPE="$2"
            shift 2
            ;;
        --detect|-d)
            AGENT_TYPE=$(detect_agent)
            echo -e "${BLUE}自动检测到代理类型: $AGENT_TYPE${NC}"
            shift
            ;;
        --skill-only)
            SKIP_SCAFFOLD=true
            shift
            ;;
        --scaffold-only)
            SKIP_SKILL=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        -*)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            ;;
        *)
            PROJECT_RALPH_DIR="$1"
            shift
            ;;
    esac
done

# 默认使用 claude
if [ -z "$AGENT_TYPE" ]; then
    AGENT_TYPE="claude"
fi

# 验证代理类型
case "$AGENT_TYPE" in
    claude|codex|gemini|openclaw)
        ;;
    *)
        echo -e "${YELLOW}⚠️  未知的代理类型: $AGENT_TYPE${NC}"
        echo "   可用代理: claude, codex, gemini, openclaw"
        echo "   使用默认值: claude"
        AGENT_TYPE="claude"
        ;;
esac

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Ralph Loop v3.2 安装程序${NC}"
echo -e "${BLUE}  代理类型: $AGENT_TYPE${NC}"
echo -e "${BLUE}  安装模式: $INSTALL_MODE${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# ============================================================
# 步骤 1: 检查 Python 环境
# ============================================================
echo -e "${CYAN}[1/3] 检查 Python 环境...${NC}"
echo ""

if command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
elif command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
    if [[ "$PYTHON_VERSION" =~ ^3\. ]]; then
        PYTHON_CMD=python
    else
        echo -e "${RED}❌ 需要 Python 3.x${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ 未找到 Python${NC}"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
echo -e "${GREEN}  ✅ Python: $PYTHON_VERSION${NC}"
echo ""

# ============================================================
# 步骤 2: 安装全局 Skill (所有代理共用)
# ============================================================
if [ "$SKIP_SKILL" = false ]; then
    echo -e "${CYAN}[2/3] 安装全局 Skill...${NC}"
    echo ""

    # 全局 Skill 目录
    GLOBAL_SKILL_DIR="$HOME/.claude/skills/ralph-loop"
    mkdir -p "$GLOBAL_SKILL_DIR"

    echo -e "${BLUE}  目标: $GLOBAL_SKILL_DIR${NC}"

    # 复制核心脚本
    echo -e "${BLUE}  复制核心脚本...${NC}"
    mkdir -p "$GLOBAL_SKILL_DIR/core"
    fetch_file "core/stop-hook.sh" "$GLOBAL_SKILL_DIR/core/stop-hook.sh"
    fetch_file "core/ralph.py" "$GLOBAL_SKILL_DIR/core/ralph.py"
    fetch_file "core/agent-detector.sh" "$GLOBAL_SKILL_DIR/core/agent-detector.sh"
    chmod +x "$GLOBAL_SKILL_DIR/core/"*.sh "$GLOBAL_SKILL_DIR/core/ralph.py" 2>/dev/null || true

    # 复制代理执行指令
    echo -e "${BLUE}  复制代理执行指令...${NC}"
    AGENT_FILES="base-executor.md executor-claude.md executor-codex.md executor-gemini.md executor-openclaw.md executor-template.md"
    fetch_dir "agents" "$GLOBAL_SKILL_DIR/agents" "$AGENT_FILES"

    # 复制模板
    echo -e "${BLUE}  复制模板文件...${NC}"
    TEMPLATE_FILES="task-template.md features-template.json init-template.sh progress-template.md verify.sh"
    fetch_dir "templates" "$GLOBAL_SKILL_DIR/templates" "$TEMPLATE_FILES"

    # 复制 Skill 定义
    fetch_file "SKILL.md" "$GLOBAL_SKILL_DIR/SKILL.md"

    # 复制参考文档
    REFERENCE_FILES="examples.md features-format.md task-planner.md best-practices.md e2e-testing.md anthropic-harnesses.md"
    fetch_dir "references" "$GLOBAL_SKILL_DIR/references" "$REFERENCE_FILES"

    echo -e "${GREEN}  ✅ 全局 Skill 安装完成${NC}"
    echo ""
else
    echo -e "${CYAN}[2/3] 跳过全局 Skill 安装 (--scaffold-only)${NC}"
    echo ""
fi

# ============================================================
# 步骤 3: 创建项目脚手架 (只有运行时数据)
# ============================================================
if [ "$SKIP_SCAFFOLD" = false ]; then
    echo -e "${CYAN}[3/3] 创建项目脚手架...${NC}"
    echo ""

    echo -e "${BLUE}  目标: $PROJECT_RALPH_DIR/${NC}"

    # 检查目标目录
    if [ -d "$PROJECT_RALPH_DIR" ]; then
        echo -e "${YELLOW}  ⚠️  目录已存在${NC}"
        if [ -t 0 ]; then
            read -p "  是否覆盖? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "  安装已取消"
                exit 1
            fi
        else
            echo -e "${BLUE}  非交互模式，保留现有数据...${NC}"
        fi
    fi

    # 创建运行时目录结构（不包含脚本，只有数据）
    mkdir -p "$PROJECT_RALPH_DIR"/{current,queue,tasks,logs,requirements}

    # 创建当前任务目录的默认文件（如果不存在）
    if [ ! -f "$PROJECT_RALPH_DIR/current/task.md" ]; then
        cat > "$PROJECT_RALPH_DIR/current/task.md" << 'EOF'
# 任务描述

## 背景

<!-- 描述任务的背景和上下文 -->

## 需求

| ID | 需求 | 来源 |
|----|------|------|
| R1 | | |

## 成功标准

- [ ]

## 约束

-

EOF
    fi

    if [ ! -f "$PROJECT_RALPH_DIR/current/features.json" ]; then
        cat > "$PROJECT_RALPH_DIR/current/features.json" << 'EOF'
[
  {
    "id": "F001",
    "description": "第一个功能",
    "requirement_refs": [],
    "steps": ["验证步骤"],
    "verify_command": "echo '验证通过'",
    "passes": false
  }
]
EOF
    fi

    if [ ! -f "$PROJECT_RALPH_DIR/current/progress.md" ]; then
        touch "$PROJECT_RALPH_DIR/current/progress.md"
    fi

    # 创建便捷命令（指向全局 Skill）
    cat > ralph << 'RALPH_SCRIPT'
#!/bin/bash
# Ralph Loop v3.2 - Shell wrapper
# 指向全局 Skill 目录的核心脚本
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"

# 项目目录
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DATA_DIR="$PROJECT_DIR/.ralph"

# 全局 Skill 目录
GLOBAL_SKILL_DIR="$HOME/.claude/skills/ralph-loop"

# 检查全局 Skill 是否存在
if [ ! -f "$GLOBAL_SKILL_DIR/core/ralph.py" ]; then
    echo "❌ Ralph Loop 全局 Skill 未安装"
    echo "   请运行: curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash"
    exit 1
fi

# 传递项目数据目录给 Python 脚本
export RALPH_DATA_DIR="$RALPH_DATA_DIR"
exec python3 "$GLOBAL_SKILL_DIR/core/ralph.py" "$@"
RALPH_SCRIPT
    chmod +x ralph

    echo -e "${GREEN}  ✅ 项目脚手架创建完成${NC}"
    echo ""
else
    echo -e "${CYAN}[3/3] 跳过项目脚手架 (--skill-only)${NC}"
    echo ""
fi

# ============================================================
# 步骤 4: 显示完成信息
# ============================================================
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  🎉 Ralph Loop v3.2 安装完成！${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$SKIP_SKILL" = false ]; then
    echo "全局 Skill:"
    echo "  📦 ~/.claude/skills/ralph-loop/"
    echo "     ├── SKILL.md           # Skill 定义"
    echo "     ├── core/              # 核心脚本 (全局共享)"
    echo "     │   ├── ralph.py"
    echo "     │   ├── stop-hook.sh"
    echo "     │   └── agent-detector.sh"
    echo "     ├── agents/            # 代理执行指令"
    echo "     ├── templates/         # 模板文件"
    echo "     └── references/        # 参考文档"
    echo ""
fi

if [ "$SKIP_SCAFFOLD" = false ]; then
    echo "项目数据:"
    echo "  📁 .ralph/"
    echo "     ├── current/           # 当前任务"
    echo "     │   ├── task.md"
    echo "     │   ├── features.json"
    echo "     │   └── progress.md"
    echo "     ├── queue/             # 任务队列"
    echo "     ├── tasks/             # 历史归档"
    echo "     └── logs/              # 日志"
    echo ""
    echo "快速开始:"
    echo "  ./ralph --new              # 创建新任务"
    echo "  ./ralph                    # 运行任务"
    echo "  ./ralph --status           # 查看状态"
    echo ""
fi

echo "升级 Skill:"
echo "  ./install.sh --skill-only  # 只更新全局 Skill"
echo ""
