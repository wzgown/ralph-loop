# Gemini CLI Executor

本文件定义 Ralph Loop 在 Gemini CLI 环境下的 Task Executor 执行指令。

> **继承**: 本文件继承 [base-executor.md](./base-executor.md) 的所有通用原则和流程。
> 本文档仅定义 Gemini CLI 特定的工具语法和配置。

## 代理信息

| 属性 | 值 |
|------|-----|
| 代理名称 | Gemini CLI (Google) |
| 配置文件 | `GEMINI.md`（项目根目录，用于持久化记忆） |
| 扩展系统 | 支持第三方集成（Dynatrace, Elastic 等） |
| 工具调用语法 | 函数调用 + `!` 前缀 + `@` 语法 |

## 核心工具

| 工具 | 用途 | Ralph Loop 场景 |
|------|------|-----------------|
| `read_file` | 读取文件 | 读取 features.json, task.md |
| `write_file` | 写入文件 | 创建代码文件 |
| `replace` | 替换内容 | 修改 passes 字段 |
| `run_shell_command` | 执行命令 | git commit, npm test |
| `glob` | 文件匹配 | 查找相关代码文件 |
| `search_file_content` | 内容搜索 | 搜索代码模式 |
| `list_directory` | 列出目录 | 查看目录结构 |

## 语法特点

- `@文件名` - 引用文件内容
- `!命令` - 执行 shell 命令
- 函数调用语法 - `tool_name: arguments`
- 支持交互式终端应用（vim, top）
- 扩展系统支持第三方集成

## 执行流程映射

### 1. 获取上下文

```
!pwd 或 run_shell_command: pwd
!git log --oneline -10
read_file: .ralph/current/features.json
read_file: .ralph/current/task.md
```

或使用 @ 语法：

```
@.ralph/current/features.json
@.ralph/current/task.md
```

### 2. 阅读需求文档

```
如果功能有 requirement_refs：
read_file: requirements/xxx.md
```

### 3. 验证基础功能

```
!bash .ralph/current/init.sh
使用 browser_agent 测试基本功能
```

### 4. 实现功能

```
使用 replace 编辑代码
!npm run test
端到端验证
```

### 5. 更新状态

```
replace .ralph/current/features.json
old: "passes": false
new: "passes": true
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

## 工具调用示例

### 读取文件

```
read_file .ralph/current/features.json
```

或使用 @ 语法：

```
@.ralph/current/features.json
```

### 编辑文件

```
replace src/component.ts
old: export function oldName()
new: export function newName()
```

### 执行命令

两种方式：

```
!npm run test
```

或

```
run_shell_command: npm run test
```

### Git 操作

```
!git add -A && git commit -m "feat: 完成功能 XXX"
```

## 扩展工具

Gemini CLI 支持以下扩展工具：

| 工具 | 用途 |
|------|------|
| `ask_user` | 向用户提问 |
| `save_memory` | 保存到 GEMINI.md |
| `write_todos` | 写入待办事项 |
| `activate_skill` | 激活技能 |
| `browser_agent` | 浏览器自动化 |
| `web_fetch` | 获取网页 |
| `google_web_search` | Google 搜索 |

使用 `browser_agent` 进行端到端测试验证。

## 配置文件示例

在项目根目录创建 `GEMINI.md`：

```markdown
# Project Memory

## Ralph Loop 任务调度

本项目使用 Ralph Loop 进行增量开发。

### 工作流程

1. read_file .ralph/current/features.json
2. 选择未完成的功能
3. 使用 replace 实现代码
4. !npm run test
5. replace features.json 更新 passes
6. !git commit
7. MISSION_COMPLETE

### 参考文档

- .ralph/agents/executor-gemini.md - Gemini CLI 执行指令
- .ralph/references/task-planner.md - 任务规划指南
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `GEMINI_SESSION` | Gemini CLI 会话标识 |
| `GOOGLE_API_KEY` | Google API 密钥 |
| `RALPH_AGENT` | 强制指定 agent 类型 |

## 注意事项

- Gemini CLI 的 GEMINI.md 用于持久化记忆
- 使用 `save_memory` 工具保存重要信息
- `browser_agent` 可用于端到端测试
