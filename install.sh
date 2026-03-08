#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Ralph Loop - 安装脚本                                                        ║
# ║                                                                              ║
# ║  将 Ralph Loop 安装到当前项目                                                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -e

# 颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.ralph}"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Ralph Loop 安装程序${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# 检查目标目录
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}⚠️  目录 $TARGET_DIR 已存在${NC}"
    read -p "是否覆盖? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "安装已取消"
        exit 1
    fi
    rm -rf "$TARGET_DIR"
fi

# 创建目录结构
echo -e "${BLUE}创建目录结构...${NC}"
mkdir -p "$TARGET_DIR"/{scripts,templates,current,queue,tasks,logs}

# 复制脚本
echo -e "${BLUE}复制脚本文件...${NC}"
cp "$SCRIPT_DIR/scripts/run-ralph.sh" "$TARGET_DIR/scripts/"
cp "$SCRIPT_DIR/scripts/stop-hook.sh" "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/"*.sh

# 复制模板
echo -e "${BLUE}复制模板文件...${NC}"
cp "$SCRIPT_DIR/templates/"* "$TARGET_DIR/templates/"

# 创建便捷命令
echo -e "${BLUE}创建便捷命令...${NC}"
cat > ralph << 'RALPH_SCRIPT'
#!/bin/bash
./.ralph/scripts/run-ralph.sh "$@"
RALPH_SCRIPT
chmod +x ralph

# 完成
echo ""
echo -e "${GREEN}✅ Ralph Loop 安装完成！${NC}"
echo ""
echo "目录结构:"
echo "  $TARGET_DIR/"
echo "  ├── scripts/        # 调度器和验证脚本"
echo "  ├── templates/      # 模板文件"
echo "  ├── current/        # 当前任务"
echo "  ├── queue/          # 任务队列"
echo "  ├── tasks/          # 历史任务归档"
echo "  └── logs/           # 循环日志"
echo ""
echo "快速开始:"
echo "  1. ./ralph --new              # 创建新任务"
echo "  2. 编辑 .ralph/current/task.md"
echo "  3. ./ralph --init             # 初始化任务"
echo "  4. 编辑 .ralph/current/features.json"
echo "  5. ./ralph                    # 运行任务"
echo ""
