---
name: ralph-loop
description: |
  Long-running task scheduler for incremental feature development. Use when:
  - User describes development requirements ("我需要实现...", "帮我开发...", "添加一个功能...")
  - User asks to create a task or feature list
  - User mentions "ralph", "ralph loop", ".ralph" directory, or "features.json"
  - User needs to convert vague requirements into structured tasks
  - User runs `./ralph` command

  AI should proactively create task.md and features.json when user describes requirements,
  rather than waiting for user to manually create files.
license: MIT
metadata:
  author: wzgown
  version: 3.3.0
  category: workflow-automation
  keywords:
    - task-scheduler
    - incremental-development
    - multi-agent
    - feature-list
    - long-running-agents
    - ralph
  compatibility:
    - claude-code
    - codex-cli
    - gemini-cli
    - openclaw
---

# Ralph Loop v3.3

基于 Anthropic "Effective harnesses for long-running agents" 最佳实践的长时运行任务调度器。

## v3.3 改进

**执行阶段 Prompt 精简**：
- 移除规划阶段的文档内容
- 根据功能类型（前端/后端）动态调整工作流程
- 移除不必要的浏览器工具强调
- 精简核心原则

## 架构：全局 Skill + 项目数据分离

```
~/.claude/skills/ralph-loop/    # 全局 Skill（脚本、模板）
├── SKILL.md                    # 本文件
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

## 核心问题与解决方案

| 问题 | 解决方案 |
|------|----------|
| AI 一次尝试做太多 | **增量工作** - 每次只做一个功能 |
| AI 过早宣布完成 | **Feature List (JSON)** - 结构化功能清单，客观验证 |
| AI 留下混乱状态 | **Clean State** - 每次会话结束确保代码可提交 |
| AI 未正确测试 | **端到端验证** - 使用浏览器自动化工具 |
| 上下文丢失 | **Progress File** - 记录已完成的工作 |

## 两种角色

### Task Planner（任务规划者）

**触发**：用户描述需求时，AI 主动创建任务文件。

**输出**（写入 `项目/.ralph/current/`）：
1. `task.md` - 任务描述（背景、需求文档引用、成功标准、约束）
2. `features.json` - 结构化功能清单（核心）
3. `requirements/` - 需求文档目录（可选）

**功能拆分原则**：
- 粒度适中：每个功能 1-2 小时可完成
- 可验证：必须有明确的 `verify_command`（事实性验收，复杂场景用脚本）
- 独立性：功能之间减少依赖

详细规范见 [references/features-format.md](./references/features-format.md)

详细流程见 [references/task-planner.md](./references/task-planner.md)

### Task Executor（任务执行者）

**触发**：运行 `./ralph` 或 `./ralph --agent <type>`

**执行步骤**：
1. 获取上下文（目录、git log、features.json）
2. 选择第一个 `passes: false` 的功能
3. 实现单个功能（编码、测试、端到端验证）
4. 更新 `passes: true`（**只修改此字段**）
5. Git commit + 更新 progress.md
6. 输出 `MISSION_COMPLETE`

**必须遵守**：
- 每次只完成一个功能
- 完成后确保代码可提交
- 只修改 `passes` 字段
- 必须输出 `MISSION_COMPLETE`

详细指令见 [agents/executor-{agent}.md](./agents/)

## 支持的 AI 代理

| 代理 | 配置文件 | 执行指令 | 特点 |
|------|----------|----------|------|
| Claude Code | `CLAUDE.md` | executor-claude.md | XML 标签工具调用 |
| Codex CLI | `AGENTS.md` | executor-codex.md | 自然语言命令 |
| Gemini CLI | `GEMINI.md` | executor-gemini.md | 函数调用语法 |
| OpenClaw | `OPENCLAW.md` | executor-openclaw.md | 自定义语法 |

### Agent 自动检测

**检测优先级**：
1. `RALPH_AGENT` 环境变量
2. Claude Code 标记 (`CLAUDE_CODE_SESSION`)
3. Codex CLI 标记 (`CODEX_SESSION`)
4. Gemini CLI 标记 (`GEMINI_SESSION`)
5. OpenClaw 标记 (`OPENCLAW_SESSION`)
6. 默认：claude

## 目录结构详解

### 全局 Skill 目录

```
~/.claude/skills/ralph-loop/
├── SKILL.md                    # Skill 元数据
├── core/                       # 核心脚本（全局共享）
│   ├── ralph.py                # Python 主调度器
│   ├── stop-hook.sh            # 验证脚本
│   └── agent-detector.sh       # 代理自动检测
├── agents/                     # 代理执行指令
│   ├── base-executor.md        # 通用执行模板
│   ├── executor-claude.md
│   ├── executor-codex.md
│   ├── executor-gemini.md
│   ├── executor-openclaw.md
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
│   └── progress.md             # 进度日志
├── queue/                      # 任务队列
├── tasks/                      # 历史任务归档
└── logs/                       # 循环日志
```

## features.json 格式

支持两种格式：

**数组格式（推荐）：**
```json
[
  {
    "id": "F001",
    "description": "功能描述",
    "requirement_refs": ["requirements/xxx.md#section"],
    "steps": ["测试步骤"],
    "verify_command": "npm run test:e2e -- --grep 'xxx'",
    "passes": false
  }
]
```

| 字段 | 说明 |
|------|------|
| `id` | 功能唯一标识（F001, F002...） |
| `description` | 简洁的功能描述 |
| `requirement_refs` | 需求文档引用（可选） |
| `steps` | 可执行的测试步骤 |
| `verify_command` | 自动化验证命令 |
| `passes` | **AI 只能修改此字段** |

## 命令参考

```bash
# 任务执行
ralph                    # 运行当前任务（自动检测 agent）
ralph --agent <type>     # 指定代理类型
ralph --detect           # 显示检测到的 agent

# 任务管理
ralph --init [file]      # 初始化新任务
ralph --new              # 创建空白任务
ralph --status           # 显示当前状态
ralph --features         # 显示功能清单
ralph --tasks            # 列出所有任务

# 队列管理
ralph --queue            # 显示任务队列
ralph --enqueue <file>   # 添加任务到队列
ralph --next             # 获取下一个任务

# 维护
ralph --archive [name]   # 归档当前任务
ralph --clean            # 检查工作区状态
```

## 安装与升级

```bash
# 安装
curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash

# 升级（只更新全局 Skill）
./install.sh --skill-only
```

## 参考文档

| 文档 | 说明 |
|------|------|
| [references/task-planner.md](./references/task-planner.md) | Task Planner 详细流程 |
| [references/features-format.md](./references/features-format.md) | features.json 格式规范 |
| [references/best-practices.md](./references/best-practices.md) | 功能拆分最佳实践 |
