# Ralph Loop v2.0

[![GitHub](https://img.shields.io/badge/GitHub-wzgown/ralph--loop-blue?logo=github)](https://github.com/wzgown/ralph-loop)

> 基于 Anthropic "Effective harnesses for long-running agents" 最佳实践
> 支持多任务队列、结构化功能清单、增量式进度跟踪

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
│  1. Initializer Agent (--init)                              │
│     • 设置环境                                               │
│     • 创建 features.json (功能清单)                          │
│     • 创建 init.sh (启动脚本)                                │
│     • 创建 progress.md (进度日志)                            │
│                                                             │
│  2. Coding Agent (默认)                                     │
│     • 读取 features.json，选择未完成功能                      │
│     • 实现单个功能                                           │
│     • 端到端测试验证                                          │
│     • 更新 passes: true                                      │
│     • Git commit + 更新 progress.md                         │
│     • 循环直到所有功能完成                                    │
└─────────────────────────────────────────────────────────────┘
```

## 支持的编码代理

Ralph Loop 支持主流 AI 编码代理，Task Planner 和 Task Executor 会根据当前代理自动适配工具语法。

| 代理 | 配置文件 | 特点 |
|------|----------|------|
| **Claude Code** | `CLAUDE.md` | XML 工具调用，MCP 扩展，Skill 系统 |
| **Codex CLI** | `AGENTS.md` | 斜杠命令，Markdown 配置 |
| **Gemini CLI** | `GEMINI.md` | `@` 文件引用，`!` 命令执行 |

### 工具对照表

| 操作 | Claude Code | Codex CLI | Gemini CLI |
|------|-------------|-----------|------------|
| 读取文件 | `Read` | 直接读取 | `read_file` |
| 创建文件 | `Write` | 直接写入 | `write_file` |
| 编辑文件 | `Edit` | 直接编辑 | `replace` |
| 执行命令 | `Bash` | `!cmd` | `!cmd` / `run_shell_command` |
| 搜索文件 | `Glob` | 内置 | `glob` |
| 搜索内容 | `Grep` | 内置 | `search_file_content` |

详见 [skill.md](./skill.md) 中的「支持的编码代理」章节。

## 快速开始

### 安装到项目

```bash
# 方式一：Git clone（推荐）
git clone https://github.com/wzgown/ralph-loop.git
cd /path/to/your/project
/path/to/ralph-loop/install.sh

# 方式二：一键安装
curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash

# 方式三：手动复制
cp -r ralph-loop /path/to/your/project/.ralph
```

### 创建新任务

```bash
# 方式一：从模板创建
./.ralph/scripts/run-ralph.sh --new
vim .ralph/current/task.md
./.ralph/scripts/run-ralph.sh --init

# 方式二：使用现有任务文件
./.ralph/scripts/run-ralph.sh --init path/to/task.md
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
./.ralph/scripts/run-ralph.sh
```

## 命令参考

```bash
# 任务管理
ralph                          # 运行当前任务（增量模式）
ralph --init                   # 初始化新任务（Initializer Agent 模式）
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

## 目录结构

```
.ralph/
├── scripts/
│   ├── run-ralph.sh      # 主调度器
│   └── stop-hook.sh      # 验证执行
│
├── templates/
│   ├── task-template.md       # 任务模板
│   ├── features-template.json # 功能清单模板
│   ├── progress-template.md   # 进度日志模板
│   └── init-template.sh       # 启动脚本模板
│
├── current/              # 当前任务
│   ├── task.md           # 任务描述
│   ├── features.json     # 功能清单 ⬅️ 核心
│   ├── progress.md       # 进度日志
│   ├── init.sh           # 启动脚本
│   └── verify.sh         # 验证脚本
│
├── queue/                # 任务队列
│   └── task-queue.json   # 待执行任务列表
│
├── tasks/                # 历史任务归档
└── logs/                 # 循环日志
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

### Initializer Agent 会话

```
[Assistant] 我将初始化任务环境...

[Tool Use] <read - task.md>
[Tool Use] <write - features.json>  # 创建功能清单
[Tool Use] <write - init.sh>        # 创建启动脚本
[Tool Use] <write - progress.md>    # 创建进度日志

[Assistant] 环境初始化完成。请编辑 features.json 添加功能列表。
```

### Coding Agent 会话

```
[Assistant] 我将开始工作...

[Tool Use] <bash - pwd>
[Tool Use] <read - features.json>
[Tool Use] <bash - git log --oneline -10>
[Tool Use] <bash - bash init.sh>    # 启动开发服务器

[Assistant] 我看到 F001 (用户登录) 尚未完成，开始实现...

[Tool Use] <edit - src/components/Login.vue>
[Tool Use] <bash - npm run test>

[Assistant] 功能已实现并测试通过，更新状态...

[Tool Use] <edit - features.json>   # 只修改 passes: true

[Assistant] 提交进度...

[Tool Use] <bash - git add -A && git commit -m "feat: 完成用户登录功能">
[Tool Use] <edit - progress.md>     # 更新进度日志

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
