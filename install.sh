#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Ralph Loop - 安装脚本 v3.1                                                  ║
# ║                                                                              ║
# ║  1. 安装脚手架到项目 .ralph/ 目录                                              ║
# ║  2. 根据代理类型安装配置文件                                                    ║
# ║  3. 支持 Claude Code, Codex CLI, Gemini CLI, OpenClaw                        ║
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
TARGET_DIR=".ralph"
AGENT_TYPE=""
AUTO_DETECT=false

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
    echo "  --help, -h           显示帮助"
    echo ""
    echo "支持的代理:"
    echo "  claude    - Claude Code (Anthropic)"
    echo "  codex     - Codex CLI (OpenAI)"
    echo "  gemini    - Gemini CLI (Google)"
    echo "  openclaw  - OpenClaw"
    echo ""
    echo "示例:"
    echo "  $0 --agent claude    安装 Claude Code 支持"
    echo "  $0 --agent codex     安装 Codex CLI 支持"
    echo "  $0 --detect          自动检测并安装"
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
            AUTO_DETECT=true
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
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# 自动检测或验证代理类型
if [ "$AUTO_DETECT" = true ]; then
    AGENT_TYPE=$(detect_agent)
    echo -e "${BLUE}自动检测到代理类型: $AGENT_TYPE${NC}"
elif [ -z "$AGENT_TYPE" ]; then
    # 默认使用 claude
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
echo -e "${BLUE}  Ralph Loop v3.1 安装程序${NC}"
echo -e "${BLUE}  代理类型: $AGENT_TYPE${NC}"
echo -e "${BLUE}  安装模式: $INSTALL_MODE${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# ============================================================
# 步骤 1: 检查并安装 Python 依赖
# ============================================================
echo -e "${CYAN}[1/4] 检查 Python 环境...${NC}"
echo ""

# 检查 Python 3
if command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
elif command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
    if [[ "$PYTHON_VERSION" =~ ^3\. ]]; then
        PYTHON_CMD=python
    else
        echo -e "${RED}❌ 需要 Python 3.x，当前版本: $(python --version 2>&1)${NC}"
        echo "   请安装 Python 3: https://www.python.org/downloads/"
        exit 1
    fi
else
    echo -e "${RED}❌ 未找到 Python${NC}"
    echo "   请安装 Python 3: https://www.python.org/downloads/"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
echo -e "${GREEN}  ✅ Python: $PYTHON_VERSION${NC}"

echo ""

# ============================================================
# 步骤 2: 安装脚手架到项目
# ============================================================
echo -e "${CYAN}[2/4] 安装脚手架到项目...${NC}"
echo ""

# 检查目标目录
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}⚠️  目录 $TARGET_DIR 已存在${NC}"
    # 检查是否在交互式终端运行
    if [ -t 0 ]; then
        read -p "是否覆盖? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "安装已取消"
            exit 1
        fi
    else
        echo -e "${BLUE}  非交互模式，自动覆盖...${NC}"
    fi
    rm -rf "$TARGET_DIR"
fi

# 创建目录结构（新结构：core/ 和 agents/）
echo -e "${BLUE}  创建目录结构...${NC}"
mkdir -p "$TARGET_DIR"/{core,agents,templates,current,queue,tasks,logs,references,requirements}

# 复制/下载核心脚本
echo -e "${BLUE}  复制核心脚本...${NC}"
if [ "$INSTALL_MODE" = "remote" ]; then
    echo -e "${BLUE}  (远程安装模式，从 GitHub 下载文件...)${NC}"
fi

fetch_file "core/stop-hook.sh" "$TARGET_DIR/core/stop-hook.sh"
fetch_file "core/ralph" "$TARGET_DIR/core/ralph"
fetch_file "core/ralph.py" "$TARGET_DIR/core/ralph.py"
fetch_file "core/agent-detector.sh" "$TARGET_DIR/core/agent-detector.sh"
chmod +x "$TARGET_DIR/core/"*.sh "$TARGET_DIR/core/ralph" "$TARGET_DIR/core/ralph.py" 2>/dev/null || true

# 复制/下载代理执行指令
echo -e "${BLUE}  复制代理执行指令...${NC}"
AGENT_FILES="base-executor.md executor-claude.md executor-codex.md executor-gemini.md executor-openclaw.md executor-template.md"
fetch_dir "agents" "$TARGET_DIR/agents" "$AGENT_FILES"

# 复制/下载模板
echo -e "${BLUE}  复制模板文件...${NC}"
TEMPLATE_FILES="task-template.md features-template.json init-template.sh progress-template.md verify.sh"
fetch_dir "templates" "$TARGET_DIR/templates" "$TEMPLATE_FILES"

# 复制/下载主 skill 文件和参考文档
fetch_file "SKILL.md" "$TARGET_DIR/SKILL.md"

REFERENCE_FILES="examples.md features-format.md task-planner.md best-practices.md e2e-testing.md anthropic-harnesses.md"
fetch_dir "references" "$TARGET_DIR/references" "$REFERENCE_FILES"

# 创建便捷命令
echo -e "${BLUE}  创建便捷命令...${NC}"
cat > ralph << 'RALPH_SCRIPT'
#!/bin/bash
# Ralph Loop v3.1 - Shell wrapper
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"
RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$RALPH_DIR/.ralph/core/ralph.py" "$@"
RALPH_SCRIPT
chmod +x ralph

echo -e "${GREEN}  ✅ 脚手架安装完成${NC}"
echo ""

# ============================================================
# 步骤 3: 安装代理配置
# ============================================================
echo -e "${CYAN}[3/4] 安装代理配置 ($AGENT_TYPE)...${NC}"
echo ""

case "$AGENT_TYPE" in
    claude)
        CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
        SKILL_NAME="ralph-loop"
        SKILL_DIR="$CLAUDE_SKILLS_DIR/$SKILL_NAME"

        mkdir -p "$CLAUDE_SKILLS_DIR"

        if [ -d "$SKILL_DIR" ]; then
            echo -e "${YELLOW}  ⚠️  Skill 已存在，更新中...${NC}"
            rm -rf "$SKILL_DIR"
        fi

        mkdir -p "$SKILL_DIR" "$SKILL_DIR/references" "$SKILL_DIR/agents"
        fetch_file "SKILL.md" "$SKILL_DIR/SKILL.md"
        fetch_dir "agents" "$SKILL_DIR/agents" "$AGENT_FILES"
        fetch_dir "references" "$SKILL_DIR/references" "$REFERENCE_FILES"

        echo -e "${GREEN}  ✅ Claude Code Skill 安装完成${NC}"
        echo -e "${BLUE}  位置: $SKILL_DIR${NC}"
        ;;

    codex)
        AGENTS_FILE="AGENTS.md"

        if [ -f "$AGENTS_FILE" ]; then
            echo -e "${YELLOW}  ⚠️  $AGENTS_FILE 已存在，追加配置...${NC}"
            echo "" >> "$AGENTS_FILE"
            echo "---" >> "$AGENTS_FILE"
            echo "" >> "$AGENTS_FILE"
        fi

        cat >> "$AGENTS_FILE" << 'EOF'
# Ralph Loop 任务调度

使用 `.ralph/SKILL.md` 作为 Ralph Loop 任务调度指南。

## 工作流程

1. 读取 `.ralph/current/features.json`
2. 选择未完成的功能
3. 实现并测试
4. 更新 passes 字段
5. Git 提交
6. 输出 MISSION_COMPLETE

## 执行指令

详细执行指令见 `.ralph/agents/executor-codex.md`

EOF

        echo -e "${GREEN}  ✅ Codex CLI 配置完成${NC}"
        echo -e "${BLUE}  配置文件: $AGENTS_FILE${NC}"
        ;;

    gemini)
        GEMINI_FILE="GEMINI.md"

        if [ -f "$GEMINI_FILE" ]; then
            echo -e "${YELLOW}  ⚠️  $GEMINI_FILE 已存在，追加配置...${NC}"
            echo "" >> "$GEMINI_FILE"
            echo "---" >> "$GEMINI_FILE"
            echo "" >> "$GEMINI_FILE"
        fi

        cat >> "$GEMINI_FILE" << 'EOF'
# Ralph Loop 任务调度

使用 `.ralph/SKILL.md` 作为 Ralph Loop 任务调度指南。

## 工作流程

1. read_file .ralph/current/features.json
2. 选择未完成的功能
3. 使用 replace 实现代码
4. !npm run test
5. replace features.json 更新 passes
6. !git commit
7. MISSION_COMPLETE

## 执行指令

详细执行指令见 `.ralph/agents/executor-gemini.md`

EOF

        echo -e "${GREEN}  ✅ Gemini CLI 配置完成${NC}"
        echo -e "${BLUE}  配置文件: $GEMINI_FILE${NC}"
        ;;

    openclaw)
        OPENCLAW_FILE="OPENCLAW.md"

        if [ -f "$OPENCLAW_FILE" ]; then
            echo -e "${YELLOW}  ⚠️  $OPENCLAW_FILE 已存在，追加配置...${NC}"
            echo "" >> "$OPENCLAW_FILE"
            echo "---" >> "$OPENCLAW_FILE"
            echo "" >> "$OPENCLAW_FILE"
        fi

        cat >> "$OPENCLAW_FILE" << 'EOF'
# Ralph Loop 任务调度

使用 `.ralph/SKILL.md` 作为 Ralph Loop 任务调度指南。

## 工作流程

1. 读取 .ralph/current/features.json
2. 选择未完成的功能
3. 实现代码
4. 运行测试
5. 更新 passes 字段
6. Git 提交
7. MISSION_COMPLETE

## 执行指令

详细执行指令见 `.ralph/agents/executor-openclaw.md`

EOF

        echo -e "${GREEN}  ✅ OpenClaw 配置完成${NC}"
        echo -e "${BLUE}  配置文件: $OPENCLAW_FILE${NC}"
        ;;
esac

echo ""

# ============================================================
# 步骤 4: 显示完成信息
# ============================================================
echo -e "${CYAN}[4/4] 安装完成${NC}"
echo ""

echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  🎉 Ralph Loop v3.1 安装完成！${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo "已安装:"
echo ""
echo "  🐍 Python 环境:"
echo "     $PYTHON_VERSION"
echo ""
echo "  📁 项目脚手架:"
echo "     $TARGET_DIR/"
echo "     ├── SKILL.md              # 主技能文件"
echo "     ├── core/                 # 核心调度器"
echo "     │   ├── ralph             # Shell wrapper"
echo "     │   ├── ralph.py          # Python 主程序 (v3.1)"
echo "     │   ├── stop-hook.sh      # 验证脚本"
echo "     │   └── agent-detector.sh # Agent 自动检测"
echo "     ├── agents/               # 代理执行指令"
echo "     │   ├── base-executor.md  # 通用执行模板"
echo "     │   ├── executor-claude.md"
echo "     │   ├── executor-codex.md"
echo "     │   ├── executor-gemini.md"
echo "     │   └── executor-openclaw.md"
echo "     ├── references/           # 参考文档"
echo "     │   ├── best-practices.md"
echo "     │   ├── e2e-testing.md"
echo "     │   └── anthropic-harnesses.md"
echo "     ├── templates/            # 模板文件"
echo "     ├── current/              # 当前任务"
echo "     ├── queue/                # 任务队列"
echo "     ├── tasks/                # 历史任务归档"
echo "     └── logs/                 # 循环日志"
echo ""

case "$AGENT_TYPE" in
    claude)
        echo "  📦 Claude Code Skill:"
        echo "     ~/.claude/skills/ralph-loop/"
        ;;
    codex)
        echo "  📦 Codex CLI 配置:"
        echo "     AGENTS.md"
        ;;
    gemini)
        echo "  📦 Gemini CLI 配置:"
        echo "     GEMINI.md"
        ;;
    openclaw)
        echo "  📦 OpenClaw 配置:"
        echo "     OPENCLAW.md"
        ;;
esac

echo ""
echo "快速开始:"
echo "  ./ralph --new              # 创建新任务"
echo "  ./ralph --init [file]      # 初始化任务"
echo "  ./ralph                    # 运行任务（自动检测 agent）"
echo "  ./ralph --detect           # 显示检测到的 agent"
echo ""
echo "切换代理:"
echo "  ./ralph --agent claude     # 使用 Claude Code"
echo "  ./ralph --agent codex      # 使用 Codex CLI"
echo "  ./ralph --agent gemini     # 使用 Gemini CLI"
echo "  ./ralph --agent openclaw   # 使用 OpenClaw"
echo ""
