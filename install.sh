#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Ralph Loop - 安装脚本                                                        ║
# ║                                                                              ║
# ║  1. 安装脚手架到项目 .ralph/ 目录                                              ║
# ║  2. 根据代理类型安装配置文件                                                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -e

# 颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR=".ralph"
AGENT_TYPE="claude"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --agent|-a)
            AGENT_TYPE="$2"
            shift 2
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --agent, -a <type>   指定代理类型 (claude/codex/gemini)，默认 claude"
            echo "  --help, -h           显示帮助"
            echo ""
            echo "示例:"
            echo "  $0 --agent claude    安装 Claude Code 支持"
            echo "  $0 --agent codex     安装 Codex CLI 支持"
            echo "  $0 --agent gemini    安装 Gemini CLI 支持"
            exit 0
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# 验证代理类型
case "$AGENT_TYPE" in
    claude|codex|gemini)
        ;;
    *)
        echo -e "${YELLOW}⚠️  未知的代理类型: $AGENT_TYPE${NC}"
        echo "   可用代理: claude, codex, gemini"
        echo "   使用默认值: claude"
        AGENT_TYPE="claude"
        ;;
esac

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Ralph Loop v3.0 安装程序${NC}"
echo -e "${BLUE}  代理类型: $AGENT_TYPE${NC}"
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
        echo -e "${YELLOW}⚠️  需要 Python 3.x，当前版本: $(python --version 2>&1)${NC}"
        echo "   请安装 Python 3: https://www.python.org/downloads/"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  未找到 Python${NC}"
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

# 创建目录结构
echo -e "${BLUE}  创建目录结构...${NC}"
mkdir -p "$TARGET_DIR"/{scripts,skills,templates,current,queue,tasks,logs}

# 复制脚本
echo -e "${BLUE}  复制脚本文件...${NC}"
cp "$SCRIPT_DIR/scripts/stop-hook.sh" "$TARGET_DIR/scripts/"
cp "$SCRIPT_DIR/scripts/ralph" "$TARGET_DIR/scripts/"
cp "$SCRIPT_DIR/scripts/ralph.py" "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/"*.sh "$TARGET_DIR/scripts/ralph" "$TARGET_DIR/scripts/ralph.py"

# 复制技能文件
echo -e "${BLUE}  复制代理执行指令...${NC}"
cp -r "$SCRIPT_DIR/skills/"* "$TARGET_DIR/skills/"

# 复制模板
echo -e "${BLUE}  复制模板文件...${NC}"
cp "$SCRIPT_DIR/templates/"* "$TARGET_DIR/templates/"

# 复制主 skill 文件和参考文档
cp "$SCRIPT_DIR/SKILL.md" "$TARGET_DIR/SKILL.md"
if [ -d "$SCRIPT_DIR/references" ]; then
    mkdir -p "$TARGET_DIR/references"
    cp -r "$SCRIPT_DIR/references/"* "$TARGET_DIR/references/"
fi

# 创建便捷命令
echo -e "${BLUE}  创建便捷命令...${NC}"
cat > ralph << 'RALPH_SCRIPT'
#!/bin/bash
# Ralph Loop v3.0 - Shell wrapper
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"
exec python3 "./.ralph/scripts/ralph.py" "$@"
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

        mkdir -p "$SKILL_DIR"
        cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
        cp -r "$SCRIPT_DIR/skills/"* "$SKILL_DIR/"
        if [ -d "$SCRIPT_DIR/references" ]; then
            cp -r "$SCRIPT_DIR/references" "$SKILL_DIR/"
        fi

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

详细执行指令见 `.ralph/skills/executor-codex.md`

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

详细执行指令见 `.ralph/skills/executor-gemini.md`

EOF

        echo -e "${GREEN}  ✅ Gemini CLI 配置完成${NC}"
        echo -e "${BLUE}  配置文件: $GEMINI_FILE${NC}"
        ;;
esac

echo ""

# ============================================================
# 步骤 4: 显示完成信息
# ============================================================
echo -e "${CYAN}[4/4] 安装完成${NC}"
echo ""

echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  🎉 Ralph Loop v3.0 安装完成！${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo "已安装:"
echo ""
echo "  🐍 Python 环境:"
echo "     $PYTHON_VERSION"
echo ""
echo "  📁 项目脚手架:"
echo "     $TARGET_DIR/"
echo "     ├── SKILL.md        # 主技能文件"
echo "     ├── scripts/        # 调度器和验证脚本"
echo "     │   ├── ralph       # Shell wrapper"
echo "     │   ├── ralph.py    # Python 主程序 (v3.0)"
echo "     │   └── stop-hook.sh"
echo "     ├── skills/         # 代理执行指令"
echo "     │   ├── executor-claude.md"
echo "     │   ├── executor-codex.md"
echo "     │   └── executor-gemini.md"
echo "     ├── references/     # 参考文档"
echo "     ├── templates/      # 模板文件"
echo "     ├── current/        # 当前任务"
echo "     ├── queue/          # 任务队列"
echo "     ├── tasks/          # 历史任务归档"
echo "     └── logs/           # 循环日志"
echo ""

case "$AGENT_TYPE" in
    claude)
        echo "  📦 Claude Code Skill:"
        echo "     ~/.claude/skills/ralph-loop/"
        echo ""
        echo "快速开始:"
        echo "  1. ./ralph --new              # 创建新任务"
        echo "  2. 编辑 .ralph/current/task.md"
        echo "  3. ./ralph --init             # 初始化任务"
        echo "  4. 编辑 .ralph/current/features.json"
        echo "  5. ./ralph --agent claude     # 运行任务"
        ;;
    codex)
        echo "  📦 Codex CLI 配置:"
        echo "     AGENTS.md"
        echo ""
        echo "快速开始:"
        echo "  1. ./ralph --new              # 创建新任务"
        echo "  2. 编辑 .ralph/current/task.md"
        echo "  3. ./ralph --init             # 初始化任务"
        echo "  4. 编辑 .ralph/current/features.json"
        echo "  5. ./ralph --agent codex      # 运行任务"
        ;;
    gemini)
        echo "  📦 Gemini CLI 配置:"
        echo "     GEMINI.md"
        echo ""
        echo "快速开始:"
        echo "  1. ./ralph --new              # 创建新任务"
        echo "  2. 编辑 .ralph/current/task.md"
        echo "  3. ./ralph --init             # 初始化任务"
        echo "  4. 编辑 .ralph/current/features.json"
        echo "  5. ./ralph --agent gemini     # 运行任务"
        ;;
esac

echo ""
echo "切换代理:"
echo "  ./ralph --agent claude    # 使用 Claude Code"
echo "  ./ralph --agent codex     # 使用 Codex CLI"
echo "  ./ralph --agent gemini    # 使用 Gemini CLI"
echo ""
