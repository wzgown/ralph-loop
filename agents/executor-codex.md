# Codex CLI Executor

本文件定义 Ralph Loop 在 Codex CLI 环境下的 Task Executor 执行指令。

> **继承**: 本文件继承 [base-executor.md](./base-executor.md) 的所有通用原则和流程。
> 本文档仅定义 Codex CLI 特定的工具语法和配置。

## 代理信息

| 属性 | 值 |
|------|-----|
| 代理名称 | Codex CLI (OpenAI) |
| 配置文件 | `AGENTS.md`（项目根目录）或 `SKILL.md` |
| 集成环境 | VS Code, Cursor, Windsurf |
| 工具调用语法 | 自然语言 + `!` 前缀执行命令 |

## 核心工具

Codex CLI 直接使用自然语言操作文件，无需特定工具名称。

| 操作 | 方式 |
|------|------|
| 读取文件 | 直接描述"读取 features.json" |
| 创建文件 | 直接描述"创建 task.md 文件，内容为..." |
| 编辑文件 | 直接描述"修改 passes 字段为 true" |
| 执行命令 | 使用 `!` 前缀 |
| 搜索文件 | 使用 `/` 斜杠命令或直接描述 |

## 语法特点

- 在 composer 中输入 `/` 触发斜杠命令
- 使用 `!` 前缀执行 shell 命令
- 配置文件使用 Markdown 格式
- 支持多编辑器集成（VS Code, Cursor, Windsurf）

## 执行流程映射

### 1. 获取上下文

```
!pwd
!git log --oneline -10
读取 .ralph/current/features.json
读取 .ralph/current/task.md
```

### 2. 阅读需求文档

```
如果功能有 requirement_refs，读取引用的文档：
读取 requirements/xxx.md
```

### 3. 验证基础功能

```
使用浏览器自动化测试基本功能
```

### 4. 实现功能

```
直接编辑代码文件
!npm run test
端到端验证
```

### 5. 更新状态

```
修改 features.json 中的 "passes": false 为 "passes": true
不要删除或修改其他内容
```

### 6. 提交进度

```
!git add -A
!git commit -m "feat: 完成功能 XXX"
更新 progress.md
```

### 7. 输出完成信号

```
MISSION_COMPLETE
```

## 命令示例

### 执行 Shell 命令

```
!pwd
!git status
!npm run test
```

### 读取和编辑文件

```
读取 .ralph/current/features.json

修改 features.json 中的 "passes": false 为 "passes": true
```

### Git 操作

```
!git add -A && git commit -m "feat: 完成功能 XXX"
```

## 斜杠命令

| 命令 | 用途 |
|------|------|
| `/init` | 创建 AGENTS.md 脚手架 |
| `/model` | 切换模型 |
| `/approvals` | 管理审批设置 |
| `/diff` | 查看变更 |
| `/review` | 代码审查 |
| `/status` | 显示状态 |
| `/compact` | 压缩对话 |
| `/mcp` | MCP 服务器管理 |

## 配置文件示例

在项目根目录创建 `AGENTS.md`：

```markdown
# Project Agent Instructions

## Ralph Loop 任务调度

本项目使用 Ralph Loop 进行增量开发。

### 工作流程

1. 读取 .ralph/current/features.json
2. 选择未完成的功能
3. 实现并测试
4. 更新 passes 字段
5. Git 提交
6. 输出 MISSION_COMPLETE

### 参考文档

- .ralph/agents/executor-codex.md - Codex CLI 执行指令
- .ralph/references/task-planner.md - 任务规划指南
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `CODEX_SESSION` | Codex CLI 会话标识 |
| `OPENAI_API_KEY` | OpenAI API 密钥 |
| `RALPH_AGENT` | 强制指定 agent 类型 |

## 注意事项

- Codex CLI 的自然语言指令需要清晰明确
- 使用 `!` 前缀确保命令被执行而非解释为描述
- 配置文件中的指令会被自动加载
