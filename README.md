# Ralph Loop v3.2

[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-orange?logo=anthropic)](https://docs.anthropic.com/claude-code)
[![GitHub](https://img.shields.io/badge/GitHub-wzgown/ralph--loop-blue?logo=github)](https://github.com/wzgown/ralph-loop)
[![Python](https://img.shields.io/badge/Python-3.8+-blue?logo=python)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**一个用于 Claude Code 的 Skill**，基于 Anthropic "Effective harnesses for long-running agents" 最佳实践。

> 支持多代理、多任务队列、结构化功能清单、增量式进度跟踪

## 这是什么？

Ralph Loop 是一个 **Claude Code Skill**，帮助你管理长时运行的软件开发任务。当你告诉 Claude Code "我需要实现用户认证功能" 时，这个 Skill 会：

1. **规划任务** - 自动创建 `task.md` 和 `features.json`
2. **增量执行** - 每次只完成一个功能，避免 AI 一次做太多
3. **验证完成** - 使用端到端测试客观验证每个功能
4. **记录进度** - 自动更新进度文件，跨会话保持上下文

## v3.2 架构重构

**核心变化：全局 Skill + 项目数据分离**

```
~/.claude/skills/ralph-loop/    # 全局 Skill（脚本、模板）
├── SKILL.md                    # Skill 定义
├── core/                       # 核心脚本（全局共享）
│   ├── ralph.py                # 主调度器
│   ├── stop-hook.sh            # 验证脚本
│   └── agent-detector.sh       # 代理检测
├── agents/                     # 代理执行指令
├── templates/                  # 模板文件
└── references/                 # 参考文档

项目/.ralph/                     # 项目数据（每个项目独立）
├── current/                    # 当前任务
├── queue/                      # 任务队列
├── tasks/                      # 历史归档
└── logs/                       # 日志
```

**优势：**
- 🚀 核心脚本全局共享，不重复安装
- 📦 项目目录只放运行时数据
- 🔄 升级时只需 `./install.sh --skill-only`
- 🎯 `.ralph/` 不再包含 SKILL.md 等定义文件

## 快速开始

### 安装

```bash
# 方式一：远程安装（推荐）
curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash

# 方式二：本地安装
git clone https://github.com/wzgown/ralph-loop.git
cd /path/to/your/project
/path/to/ralph-loop/install.sh --agent claude
```

### 升级

```bash
# 只更新全局 Skill（不影响项目数据）
./install.sh --skill-only

# 远程升级
curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash -s -- --skill-only
```

### 系统要求

- **Python 3.8+**（必需，无其他依赖）

## 核心设计

Ralph Loop 是一个**长时运行任务调度器**，解决 AI 代理在多上下文窗口中持续工作的挑战。

### 设计原则（来自 Anthropic 研究）

| 问题 | 解决方案 |
|------|----------|
| AI 一次尝试做太多 | **增量工作** - 每次只做一个功能 |
| AI 过早宣布完成 | **Feature List (JSON)** - 结构化功能清单，客观验证 |
| AI 留下混乱状态 | **Clean State** - 每次会话结束确保代码可提交 |
| AI 未正确测试 | **端到端验证** - 使用浏览器自动化工具 |
| 上下文丢失 | **Progress File** - 记录已完成的工作 |

### 两种工作模式

```
┌─────────────────────────────────────────────────────────────┐
│  1. Task Planner（任务规划者）                               │
│     • 理解用户需求                                           │
│     • 创建 task.md (任务描述)                                │
│     • 创建 features.json (功能清单)                          │
│     • 创建 init.sh / verify.sh                              │
│                                                             │
│  2. Task Executor（任务执行者）                              │
│     • 读取 features.json，选择未完成功能                      │
│     • 实现单个功能                                           │
│     • 端到端测试验证                                          │
│     • 更新 passes: true                                      │
│     • Git commit + 更新 progress.md                         │
│     • 循环直到所有功能完成                                    │
└─────────────────────────────────────────────────────────────┘
```

## 支持的编码代理

| 代理 | 执行指令 | 特点 |
|------|----------|------|
| **Claude Code** | [executor-claude.md](./agents/executor-claude.md) | XML 工具调用，MCP 扩展 |
| **Codex CLI** | [executor-codex.md](./agents/executor-codex.md) | 自然语言命令 |
| **Gemini CLI** | [executor-gemini.md](./agents/executor-gemini.md) | 函数调用语法 |
| **OpenClaw** | [executor-openclaw.md](./agents/executor-openclaw.md) | 自定义语法 |

### 工具对照表

| 操作 | Claude Code | Codex CLI | Gemini CLI |
|------|-------------|-----------|------------|
| 读取文件 | `Read` | 直接读取 | `read_file` |
| 创建文件 | `Write` | 直接写入 | `write_file` |
| 编辑文件 | `Edit` | 直接编辑 | `replace` |
| 执行命令 | `Bash` | `!cmd` | `!cmd` |

## 命令参考

```bash
# 任务执行
ralph                          # 运行当前任务（增量模式）
ralph --agent <type>           # 指定代理类型 (claude/codex/gemini/openclaw)
ralph --detect                 # 显示检测到的代理类型

# 任务管理
ralph --init [file]            # 初始化新任务
ralph --new                    # 创建空白任务
ralph --status                 # 显示当前状态
ralph --features               # 显示功能清单
ralph --progress               # 显示进度日志
ralph --tasks                  # 列出所有任务

# 队列管理
ralph --queue                  # 显示任务队列
ralph --enqueue <file>         # 添加任务到队列
ralph --next                   # 从队列获取下一个任务

# 维护
ralph --archive [name]         # 归档当前任务
ralph --clean                  # 检查工作区状态
ralph --help                   # 显示帮助
```

### 环境变量

```bash
RALPH_AGENT=claude             # 默认代理类型
RALPH_DATA_DIR=/path/.ralph    # 项目数据目录（自动设置）
MAX_FEATURE_RETRIES=3          # 单个功能最大重试次数
CLAUDE_TIMEOUT=1800            # 单次执行超时（秒）
```

## 功能清单 (features.json) 规范

### 支持两种格式

**数组格式（推荐）：**
```json
[
  {
    "id": "F001",
    "description": "用户登录功能",
    "requirement_refs": ["requirements/auth.md#login"],
    "steps": ["打开登录页面", "输入凭证", "验证跳转"],
    "verify_command": "npm run test:e2e -- --grep 'login'",
    "passes": false
  }
]
```

**对象格式（兼容）：**
```json
{
  "features": [
    { "id": "F001", ... }
  ]
}
```

### 字段说明

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 功能唯一标识（如 F001） |
| `description` | string | ✅ | 功能描述 |
| `requirement_refs` | array | | 需求文档引用 |
| `steps` | array | | 测试步骤 |
| `verify_command` | string | | 验证命令 |
| `passes` | boolean | ✅ | 是否通过（**AI 只修改此字段**） |

### AI 行为约束

> ⚠️ **重要**：AI 只能修改 `passes` 字段，不允许删除或修改其他内容。

## 终端 UI 预览

```
╭────────────────────────────────────────────────────────────╮
│  🔄 Ralph Loop v3.2                          Claude Agent  │
├────────────────────────────────────────────────────────────┤
│  📋 任务: 实现用户认证系统                                  │
│  📊 进度: ████████░░░░░░░░░░░░ 3/8 功能 (37%)             │
│  ⏱️  运行时间: 00:15:32                                     │
╰────────────────────────────────────────────────────────────╯

┌── 功能清单 ────────────────────────────────────────────────┐
│ ✅ F1 用户注册                                              │
│ ✅ F2 用户登录                                              │
│ 🔄 F3 密码重置 ← 当前                                       │
│ ⏳ F4 邮箱验证                                              │
└────────────────────────────────────────────────────────────┘
```

## 典型工作流程

### Task Planner 会话

```
用户：我需要实现一个用户个人资料编辑功能

AI（Task Planner）：
    我来帮你创建这个任务...

    1. 创建 .ralph/current/task.md：
       - 背景：用户需要编辑个人资料
       - 成功标准：头像、昵称、简介编辑
       - 约束：头像 2MB 限制

    2. 创建 .ralph/current/features.json：
       - F001: 个人资料编辑页面 UI
       - F002: 头像上传和裁剪
       - F003: 表单验证
       - F004: API 集成

    任务已创建，运行 ./ralph 开始执行。
```

### Task Executor 会话

```
AI（Task Executor）：
    我将开始工作...

    1. 读取 features.json
    2. 选择 F001（passes: false）
    3. 实现功能
    4. 运行测试
    5. 更新 passes: true
    6. Git commit

    MISSION_COMPLETE
```

## 目录结构详解

### 全局 Skill 目录

```
~/.claude/skills/ralph-loop/
├── SKILL.md                    # Skill 元数据（Claude Code 识别）
├── core/                       # 核心脚本（全局共享）
│   ├── ralph.py                # Python 主调度器
│   ├── stop-hook.sh            # 验证脚本
│   └── agent-detector.sh       # 代理自动检测
├── agents/                     # 代理执行指令
│   ├── base-executor.md        # 通用执行模板
│   ├── executor-claude.md      # Claude Code
│   ├── executor-codex.md       # Codex CLI
│   ├── executor-gemini.md      # Gemini CLI
│   ├── executor-openclaw.md    # OpenClaw
│   └── executor-template.md    # 新代理模板
├── templates/                  # 模板文件
│   ├── task-template.md
│   ├── features-template.json
│   └── ...
└── references/                 # 参考文档
    ├── best-practices.md
    ├── e2e-testing.md
    └── ...
```

### 项目数据目录

```
项目/.ralph/
├── current/                    # 当前任务
│   ├── task.md                 # 任务描述
│   ├── features.json           # 功能清单 ⬅️ 核心
│   ├── requirements/           # 需求文档（可选）
│   ├── progress.md             # 进度日志
│   ├── init.sh                 # 启动脚本
│   └── verify.sh               # 验证脚本
├── queue/                      # 任务队列
│   └── task-queue.json
├── tasks/                      # 历史任务归档
└── logs/                       # 循环日志
```

## 添加新代理支持

1. 复制模板：
   ```bash
   cp ~/.claude/skills/ralph-loop/agents/executor-template.md \
      ~/.claude/skills/ralph-loop/agents/executor-newagent.md
   ```

2. 编辑 `executor-newagent.md`，填写代理特定的工具调用语法

3. 更新 `core/agent-detector.sh` 添加检测逻辑

4. 提交 PR 或 issue 反馈

## 故障排除

### 全局 Skill 未安装

```
❌ Ralph Loop 全局 Skill 未安装
   请运行: curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash
```

### AI 一次做太多

- 检查 features.json 是否功能粒度太粗
- 确保每个功能可以在一个会话内完成

### AI 过早标记完成

- 强化验证脚本
- 添加端到端测试命令
- 使用浏览器自动化验证

## 参考资料

- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) - Anthropic Engineering Blog
- [references/](./references/) - 详细参考文档

## License

MIT License - 详见 [LICENSE](LICENSE)
