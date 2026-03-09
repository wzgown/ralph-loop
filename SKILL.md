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
  version: 3.0.0
  category: workflow-automation
---

# Ralph Loop

基于 Anthropic "Effective harnesses for long-running agents" 最佳实践的长时运行任务调度器。

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

**输出**：
1. `task.md` - 任务描述（背景、需求文档引用、成功标准、约束）
2. `features.json` - 结构化功能清单（核心）
3. `requirements/` - 需求文档目录（可选，存放详细业务规则）
4. `init.sh` - 环境初始化脚本
5. `verify.sh` - 验证脚本

**功能拆分原则**：
- 粒度适中：每个功能 1-2 小时可完成
- 可验证：必须有明确的 `verify_command`
- 独立性：功能之间减少依赖

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

详细指令见 [skills/executor-{agent}.md](./skills/)

## 支持的编码代理

| 代理 | 配置文件 | 执行指令 |
|------|----------|----------|
| Claude Code | `CLAUDE.md` | executor-claude.md |
| Codex CLI | `AGENTS.md` | executor-codex.md |
| Gemini CLI | `GEMINI.md` | executor-gemini.md |

```bash
./ralph --agent claude    # Claude Code（默认）
./ralph --agent codex     # Codex CLI
./ralph --agent gemini    # Gemini CLI
```

## 目录结构

```
.ralph/
├── scripts/
│   ├── ralph            # Shell wrapper
│   ├── ralph.py         # 主调度器（Python）
│   └── stop-hook.sh     # 验证脚本
├── skills/              # 代理执行指令
│   ├── executor-claude.md
│   ├── executor-codex.md
│   └── executor-gemini.md
├── templates/           # 模板文件
├── current/             # 当前任务
│   ├── task.md          # 任务描述
│   ├── features.json    # 功能清单 ⬅️ 核心
│   ├── requirements/    # 需求文档（可选）
│   ├── progress.md      # 进度日志
│   ├── init.sh          # 启动脚本
│   └── verify.sh        # 验证脚本
├── queue/               # 任务队列
├── tasks/               # 历史任务归档
├── logs/                # 循环日志
└── references/          # 参考文档
```

## features.json 核心字段

```json
{
  "id": "F001",
  "description": "功能描述",
  "requirement_refs": ["requirements/xxx.md#section"],
  "steps": ["测试步骤"],
  "verify_command": "npm run test:e2e -- --grep 'xxx'",
  "passes": false
}
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
ralph                    # 运行当前任务
ralph --agent <type>     # 指定代理类型
ralph --init [file]      # 初始化新任务
ralph --new              # 创建空白任务
ralph --status           # 显示当前状态
ralph --features         # 显示功能清单
ralph --tasks            # 列出所有任务
```
