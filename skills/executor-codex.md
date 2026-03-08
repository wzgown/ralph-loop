# Codex CLI Executor

本文件定义 Ralph Loop 在 Codex CLI 环境下的 Task Executor 执行指令。

## 代理信息

- **代理名称**：Codex CLI (OpenAI)
- **配置文件**：`AGENTS.md`（项目根目录）或 `SKILL.md`
- **集成环境**：VS Code, Cursor, Windsurf

## 核心工具

Codex CLI 直接使用自然语言操作文件，无需特定工具名称。

| 操作 | 方式 |
|------|------|
| 读取文件 | 直接描述"读取 features.json" |
| 创建文件 | 直接描述"创建 task.md 文件，内容为..." |
| 编辑文件 | 直接描述"修改 passes 字段为 true" |
| 执行命令 | 使用 `!` 前缀 |
| 搜索文件 | 使用 `/` 斜杠命令或直接描述 |

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

## 语法特点

- 在 composer 中输入 `/` 触发斜杠命令
- 使用 `!` 前缀执行 shell 命令
- 配置文件使用 Markdown 格式
- 支持多编辑器集成

## Task Executor 工作流

### 必须遵守的原则

1. **增量工作**：每次只完成一个 `passes: false` 的功能
2. **干净状态**：完成后确保代码可提交（无语法错误、测试通过）
3. **只修改 passes**：只能将 `passes: false` 改为 `passes: true`
4. **端到端验证**：使用浏览器自动化工具测试功能
5. **提交进度**：完成后 git commit 并更新 progress.md
6. **完成信号**：必须单独一行输出 `MISSION_COMPLETE`

### 执行步骤

```
1. 获取上下文
   - !pwd
   - !git log --oneline -10
   - 读取 .ralph/current/features.json

2. 选择第一个 passes: false 的功能

3. 验证基础功能
   - !bash .ralph/current/init.sh 启动开发服务器
   - 使用浏览器自动化测试基本功能
   - 发现现有 bug 先修复

4. 实现单个功能
   - 直接编辑代码文件
   - !npm run test
   - 端到端验证

5. 更新状态
   - 修改 features.json 中的 passes 字段为 true
   - 不要删除或修改其他内容

6. 提交进度
   - !git add -A
   - !git commit -m "feat: 完成功能 XXX"

7. 更新 progress.md
   - 添加会话记录

8. 输出完成信号
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

## 禁止事项

- ❌ 不要一次实现多个功能
- ❌ 不要删除或修改 features.json 中的测试步骤
- ❌ 不要在未测试的情况下标记 passes: true
- ❌ 不要留下未提交的代码
- ❌ 不要修改已跳过的功能（达到最大重试次数）

## 配置文件示例

在项目根目录创建 `AGENTS.md`：

```markdown
# Project Agent Instructions

使用 .ralph/skill.md 作为 Ralph Loop 任务调度指南。

## 工作流程

1. 读取 .ralph/current/features.json
2. 选择未完成的功能
3. 实现并测试
4. 更新 passes 字段
5. Git 提交
6. 输出 MISSION_COMPLETE
```
