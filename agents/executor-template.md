# Executor Template

本模板用于创建新的 AI Agent 执行指令文件。

> **使用方法**: 复制此文件为 `executor-{agent-name}.md`，然后填写各部分的占位符内容。

---

# {Agent Name} Executor

本文件定义 Ralph Loop 在 {Agent Name} 环境下的 Task Executor 执行指令。

> **继承**: 本文件继承 [base-executor.md](./base-executor.md) 的所有通用原则和流程。
> 本文档仅定义 {Agent Name} 特定的工具语法和配置。

## 代理信息

| 属性 | 值 |
|------|-----|
| 代理名称 | {Agent Name} ({Provider}) |
| 配置文件 | `{CONFIG_FILE}.md`（项目根目录） |
| 集成环境 | {IDE/Editor 支持} |
| 工具调用语法 | {语法描述} |

## 核心工具

| 工具 | 用途 | Ralph Loop 场景 |
|------|------|-----------------|
| `{tool_name}` | {用途描述} | {Ralph Loop 场景} |
| ... | ... | ... |

## 语法特点

- {特点 1}
- {特点 2}
- {特点 3}

## 执行流程映射

### 1. 获取上下文

```
{agent specific syntax} pwd
{agent specific syntax} git log --oneline -10
{agent specific syntax} .ralph/current/features.json
{agent specific syntax} .ralph/current/task.md
```

### 2. 阅读需求文档

```
如果功能有 requirement_refs：
{agent specific syntax} requirements/xxx.md
```

### 3. 验证基础功能

```
{browser automation syntax} 测试基本功能
```

### 4. 实现功能

```
{edit syntax} 编辑代码
{test syntax} npm run test
端到端验证
```

### 5. 更新状态

```
{edit syntax} .ralph/current/features.json
修改 "passes": false 为 "passes": true
```

### 6. 提交进度

```
{git syntax} git add -A
{git syntax} git commit -m "feat: 完成功能 XXX"
更新 progress.md
```

### 7. 输出完成信号

```
MISSION_COMPLETE
```

## 工具调用示例

### 读取文件

```
{example syntax for reading files}
```

### 编辑文件

```
{example syntax for editing files}
```

### 执行命令

```
{example syntax for executing commands}
```

### Git 操作

```
{example syntax for git operations}
```

## 浏览器自动化

{描述该 agent 支持的浏览器自动化工具和方法}

| 工具 | 用途 |
|------|------|
| `{browser_tool}` | {用途} |
| ... | ... |

## 配置文件示例

在项目根目录创建 `{CONFIG_FILE}.md`：

```markdown
# Project Instructions

## Ralph Loop 任务调度

本项目使用 Ralph Loop 进行增量开发。

### 工作流程

1. {read syntax} .ralph/current/features.json
2. 选择未完成的功能
3. {edit syntax} 实现代码
4. {test syntax} npm run test
5. {edit syntax} 更新 passes
6. {git syntax} git commit
7. MISSION_COMPLETE

### 参考文档

- .ralph/agents/executor-{agent-name}.md - {Agent Name} 执行指令
- .ralph/references/task-planner.md - 任务规划指南
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `{AGENT}_SESSION` | {Agent Name} 会话标识 |
| `{API_KEY_VAR}` | API 密钥 |
| `RALPH_AGENT` | 强制指定 agent 类型 |

## 注意事项

- {注意事项 1}
- {注意事项 2}
- {注意事项 3}

---

## 添加新 Agent 的步骤

1. **复制模板**
   ```bash
   cp agents/executor-template.md agents/executor-{agent-name}.md
   ```

2. **填写占位符**
   - 替换所有 `{placeholder}` 为实际内容
   - 确保工具语法正确

3. **更新检测脚本**
   - 编辑 `core/agent_detector.py`
   - 添加新 agent 的检测逻辑

4. **更新安装脚本**
   - 编辑 `install.sh`
   - 添加新 agent 的安装支持

5. **更新 SKILL.md**
   - 在"支持的 AI 代理"表格中添加新行

6. **测试**
   - 在新 agent 环境中测试完整工作流
   - 确认所有功能正常

7. **提交 PR**
   - 提交到主仓库
   - 在 PR 描述中说明新 agent 的特点
