# Ralph Loop v3.0

[![GitHub](https://img.shields.io/badge/GitHub-wzgown/ralph--loop-blue?logo=github)](https://github.com/wzgown/ralph-loop)
[![Python](https://img.shields.io/badge/Python-3.8+-blue?logo=python)](https://www.python.org/)

> 基于 Anthropic "Effective harnesses for long-running agents" 最佳实践
> 支持多代理、多任务队列、结构化功能清单、增量式进度跟踪

## v3.0 新特性

- 🐍 **Python 重写** - 原生 UTF-8 支持，彻底解决中文编码问题
- 🎨 **Rich 终端 UI** - 现代化的进度显示和状态面板
- 📊 **实时状态** - 直观的功能进度条和任务状态

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

Ralph Loop 支持三种主流 AI 编码代理，每种代理有独立的执行指令文件。

| 代理 | 配置文件 | 执行指令 | 特点 |
|------|----------|----------|------|
| **Claude Code** | `CLAUDE.md` | [executor-claude.md](./skills/executor-claude.md) | XML 工具调用，MCP 扩展 |
| **Codex CLI** | `AGENTS.md` | [executor-codex.md](./skills/executor-codex.md) | 斜杠命令，Markdown 配置 |
| **Gemini CLI** | `GEMINI.md` | [executor-gemini.md](./skills/executor-gemini.md) | `@` 文件引用，`!` 命令执行 |

### 工具对照表

| 操作 | Claude Code | Codex CLI | Gemini CLI |
|------|-------------|-----------|------------|
| 读取文件 | `Read` | 直接读取 | `read_file` |
| 创建文件 | `Write` | 直接写入 | `write_file` |
| 编辑文件 | `Edit` | 直接编辑 | `replace` |
| 执行命令 | `Bash` | `!cmd` | `!cmd` / `run_shell_command` |

## 快速开始

### 安装到项目

```bash
# 方式一：Git clone（推荐）
git clone https://github.com/wzgown/ralph-loop.git
cd /path/to/your/project
/path/to/ralph-loop/install.sh --agent claude   # 安装 Claude Code 支持（默认）

# 方式二：一键安装
curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash -s -- --agent claude
```

### 系统要求

- **Python 3.8+**（必需，无其他依赖）

### 终端 UI 预览

```
╭────────────────────────────────────────────────────────────╮
│  🔄 Ralph Loop v3.0                          Claude Agent  │
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

### 创建新任务

**方式一：使用 Skill（推荐）**

直接向 AI 编码代理描述你的需求，AI 会自动帮你创建 task.md 和 features.json：

```
用户：我需要实现一个用户个人资料编辑功能，用户可以修改头像、昵称、个人简介

AI：我来帮你创建这个任务...
    [创建 .ralph/current/task.md]
    [创建 .ralph/current/features.json]
    [创建 .ralph/current/init.sh]

    任务已创建，运行 ./ralph 开始执行。
```

**方式二：命令行模板**

```bash
./ralph --new                    # 创建空白任务模板
vim .ralph/current/task.md       # 编辑任务描述
./ralph --init                   # 初始化任务环境
```

**方式三：使用现有任务文件**

```bash
./ralph --init path/to/task.md   # 从现有文件初始化
```

### 配置功能清单

编辑 `.ralph/current/features.json`:

```json
{
  "task_id": "F-20260306-001",
  "task_name": "用户登录功能",
  "created_at": "2026-03-06T10:00:00+08:00",
  "features": [
    {
      "id": "F001",
      "category": "functional",
      "description": "用户可以使用邮箱和密码登录",
      "priority": "high",
      "steps": [
        "打开登录页面",
        "输入邮箱和密码",
        "点击登录按钮",
        "验证跳转到首页"
      ],
      "verify_command": "npm run test:e2e -- --grep 'login'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    }
  ]
}
```

### 运行

```bash
./ralph                          # 使用默认代理（claude）
./ralph --agent codex            # 使用 Codex CLI
./ralph --agent gemini           # 使用 Gemini CLI
```

## 命令参考

```bash
# 任务管理
ralph                          # 运行当前任务（增量模式）
ralph --agent <type>           # 指定代理类型运行 (claude/codex/gemini)
ralph --init [file]            # 初始化新任务
ralph --new                    # 创建空白任务
ralph --status                 # 显示当前状态
ralph --features               # 显示功能清单
ralph --progress               # 显示进度日志
ralph --tasks                  # 列出所有任务

# 队列管理
ralph --queue                  # 显示任务队列
ralph --enqueue <file>         # 添加任务到队列
ralph --dequeue <id>           # 从队列移除任务
ralph --next                   # 从队列获取下一个任务

# 维护
ralph --archive [name]         # 归档当前任务
ralph --reset                  # 重置失败日志
ralph --clean                  # 检查工作区状态
ralph --help                   # 显示帮助
```

### 环境变量

```bash
RALPH_AGENT=claude             # 默认代理类型
MAX_FEATURE_RETRIES=3          # 单个功能最大重试次数
CLAUDE_TIMEOUT=1800            # 单次执行超时（秒）
```

## 目录结构

```
.ralph/
├── scripts/
│   ├── ralph                # Shell wrapper
│   ├── ralph.py             # 主调度器（Python）
│   └── stop-hook.sh         # 验证执行
│
├── skills/                  # 代理执行指令
│   ├── executor-claude.md
│   ├── executor-codex.md
│   └── executor-gemini.md
│
├── templates/
│   ├── task-template.md       # 任务模板
│   ├── features-template.json # 功能清单模板
│   ├── progress-template.md   # 进度日志模板
│   └── init-template.sh       # 启动脚本模板
│
├── current/                 # 当前任务
│   ├── task.md              # 任务描述
│   ├── features.json        # 功能清单 ⬅️ 核心
│   ├── requirements/        # 需求文档（可选）
│   ├── progress.md          # 进度日志
│   ├── init.sh              # 启动脚本
│   └── verify.sh            # 验证脚本
│
├── queue/                   # 任务队列
│   └── task-queue.json      # 待执行任务列表
│
├── tasks/                   # 历史任务归档
├── logs/                    # 循环日志
└── references/              # 参考文档
```

## 功能清单 (features.json) 规范

### 为什么用 JSON 而不是 Markdown？

根据 Anthropic 研究，AI 模型更不容易不当地修改或覆盖 JSON 文件，相比 Markdown 文件。

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 功能唯一标识（如 F001） |
| `category` | string | 分类：functional, ui, api, etc. |
| `description` | string | 功能描述 |
| `priority` | string | 优先级：high, medium, low |
| `steps` | array | 测试步骤 |
| `verify_command` | string | 验证命令 |
| `passes` | boolean | 是否通过（**只修改此字段**） |
| `completed_at` | string | 完成时间 |
| `notes` | string | 备注 |

### AI 行为约束

> ⚠️ **重要**：AI 只能修改 `passes` 字段，不允许删除或修改其他内容。

```
It is unacceptable to remove or edit tests because this could lead to missing or buggy functionality.
```

## 进度日志 (progress.md)

每个会话结束后，AI 应该更新进度日志：

```markdown
# Ralph Progress Log

## 任务信息
- **任务ID**: F-20260306-001
- **任务名称**: 用户登录功能
- **开始时间**: 2026-03-06T10:00:00+08:00

---

## 会话记录

### #20260306-101530
- 时间: 2026-03-06T10:15:30+08:00
- 循环: #1
- 状态: ✅ 功能完成
- 进度: 1/5
- 完成功能: F001 - 用户登录
```

## 典型工作流程

### Task Planner 会话（使用 Skill）

```
用户：我需要实现一个用户个人资料编辑功能

AI（Task Planner）：
    我来帮你创建这个任务...

    1. 创建 task.md：
       - 背景：用户需要编辑个人资料
       - 成功标准：头像、昵称、简介编辑
       - 约束：头像 2MB 限制

    2. 创建 features.json：
       - F001: 个人资料编辑页面 UI
       - F002: 头像上传和裁剪
       - F003: 表单验证
       - F004: 实时预览
       - F005: API 集成

    3. 创建 init.sh 和 verify.sh

    任务已创建，运行 ./ralph 开始执行。
```

### Task Executor 会话

```
AI（Task Executor）：
    我将开始工作...

    1. 读取 features.json
    2. 选择 F001（passes: false）
    3. 启动开发服务器
    4. 实现 F001 功能
    5. 运行测试
    6. 更新 passes: true
    7. Git commit

    MISSION_COMPLETE
```

## 端到端测试

Anthropic 研究强调，AI 必须使用浏览器自动化工具进行端到端测试：

```javascript
// 示例：Playwright 测试
test('用户登录', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-testid="email"]', 'test@example.com');
  await page.fill('[data-testid="password"]', 'password123');
  await page.click('[data-testid="login-button"]');
  await expect(page).toHaveURL('/');
});
```

## 故障排除

### AI 一次做太多

- 检查 features.json 是否功能粒度太粗
- 确保每个功能可以在一个会话内完成

### AI 过早标记完成

- 强化验证脚本
- 添加端到端测试命令
- 使用浏览器自动化验证

### AI 留下混乱状态

- 检查 git status
- 运行 `ralph --clean` 检查状态
- 要求 AI 提交前运行测试

## 参考资料

- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) - Anthropic Engineering Blog
- [Claude 4 Prompting Guide](https://docs.anthropic.com/claude/docs/prompting)

## 关键要点

1. **features.json 必须存在** - 没有功能清单会报错
2. **每次只做一个功能** - 增量式工作
3. **只修改 passes 字段** - 不要删除测试步骤
4. **端到端验证** - 使用浏览器自动化
5. **干净状态** - Git commit + 更新 progress.md
6. **MISSION_COMPLETE** - AI 必须输出完成信号
7. **支持多代理** - Claude Code / Codex CLI / Gemini CLI
