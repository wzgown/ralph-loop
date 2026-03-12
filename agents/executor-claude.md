# Claude Code Executor

本文件定义 Ralph Loop 在 Claude Code 环境下的 Task Executor 执行指令。

> **继承**: 本文件继承 [base-executor.md](./base-executor.md) 的所有通用原则和流程。
> 本文档仅定义 Claude Code 特定的工具语法和配置。

## 代理信息

| 属性 | 值 |
|------|-----|
| 代理名称 | Claude Code (Anthropic) |
| 配置文件 | `CLAUDE.md`（项目根目录） |
| Skill 安装位置 | `~/.claude/skills/ralph-loop/` |
| 工具调用语法 | XML 标签格式 |

## 核心工具

| 工具 | 用途 | Ralph Loop 场景 |
|------|------|-----------------|
| `Read` | 读取文件 | 读取 features.json, task.md |
| `Write` | 创建新文件 | 创建代码文件 |
| `Edit` | 编辑文件 | 修改 passes 字段 |
| `Bash` | 执行命令 | git commit, npm test |
| `Glob` | 文件搜索 | 查找相关代码文件 |
| `Grep` | 内容搜索 | 搜索代码模式 |
| `Task` | 启动子代理 | 并行任务 |
| `Skill` | 调用技能 | `/commit`, `/test` |

## 语法特点

- 工具调用通过 XML 标签格式
- 支持 MCP (Model Context Protocol) 扩展
- 权限控制通过 `allowedTools` 配置
- 内置浏览器自动化支持

## 执行流程映射

### 1. 获取上下文

```
使用 Bash 工具：
- command: pwd

使用 Bash 工具：
- command: git log --oneline -10

使用 Read 工具：
- file_path: .ralph/current/features.json

使用 Read 工具：
- file_path: .ralph/current/task.md
```

### 2. 阅读需求文档

```
如果功能有 requirement_refs，使用 Read 工具：
- file_path: requirements/xxx.md
```

### 3. 验证基础功能

```
使用 Bash 工具：
- command: bash .ralph/current/init.sh

使用 mcp__chrome-devtools__navigate_page 导航到测试页面
使用 mcp__chrome-devtools__take_snapshot 获取页面状态
```

### 4. 实现功能

```
使用 Edit 或 Write 工具编写代码

使用 Bash 工具：
- command: npm run test

使用浏览器自动化工具验证
```

### 5. 更新状态

```
使用 Edit 工具：
- file_path: .ralph/current/features.json
- old_string: "passes": false
- new_string: "passes": true
```

### 6. 提交进度

```
使用 Bash 工具：
- command: git add -A && git commit -m "feat: 完成功能 XXX"

使用 Edit 工具更新 progress.md
```

### 7. 输出完成信号

```
MISSION_COMPLETE
```

## 工具调用示例

### 读取文件

```
使用 Read 工具读取 .ralph/current/features.json
```

### 修改 passes 字段

```
使用 Edit 工具：
- file_path: .ralph/current/features.json
- old_string: "passes": false
- new_string: "passes": true
```

### 执行测试

```
使用 Bash 工具：
- command: npm run test:e2e -- --grep 'feature-name'
```

### Git 提交

```
使用 Bash 工具：
- command: git add -A && git commit -m "feat: 完成功能 XXX"
```

## 浏览器自动化

Claude Code 通过 MCP 支持 Chrome DevTools 协议：

| 工具 | 用途 |
|------|------|
| `mcp__chrome-devtools__navigate_page` | 导航到页面 |
| `mcp__chrome-devtools__take_snapshot` | 获取页面快照 |
| `mcp__chrome-devtools__click` | 点击元素 |
| `mcp__chrome-devtools__fill` | 填写表单 |
| `mcp__chrome-devtools__take_screenshot` | 截图 |
| `mcp__chrome-devtools__evaluate_script` | 执行 JavaScript |

### E2E 测试示例

```
1. 使用 mcp__chrome-devtools__navigate_page 导航到 http://localhost:3000
2. 使用 mcp__chrome-devtools__take_snapshot 检查页面结构
3. 使用 mcp__chrome-devtools__fill 填写登录表单
4. 使用 mcp__chrome-devtools__click 点击登录按钮
5. 使用 mcp__chrome-devtools__take_screenshot 验证登录成功
```

## 配置文件示例

在项目根目录的 `CLAUDE.md` 中添加：

```markdown
# 项目配置

## Ralph Loop 集成

本项目使用 Ralph Loop 进行增量开发。

### 工作流程

1. 读取 .ralph/current/features.json
2. 选择未完成的功能
3. 实现并测试
4. 更新 passes 字段
5. Git 提交
6. 输出 MISSION_COMPLETE

### 参考文档

- .ralph/agents/executor-claude.md - Claude Code 执行指令
- .ralph/references/task-planner.md - 任务规划指南
```

## 常用斜杠命令

| 命令 | 用途 |
|------|------|
| `/commit` | 创建 Git 提交 |
| `/review-pr` | 审查 PR |
| `/test` | 运行测试 |
| `/help` | 获取帮助 |

## 环境变量

| 变量 | 说明 |
|------|------|
| `CLAUDE_CODE_SESSION` | Claude Code 会话标识 |
| `CLAUDE_MD_FILE` | CLAUDE.md 文件路径 |
| `CLAUDE_PROJECT` | 项目名称 |
| `RALPH_AGENT` | 强制指定 agent 类型 |
