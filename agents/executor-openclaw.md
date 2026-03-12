# OpenClaw Executor

本文件定义 Ralph Loop 在 OpenClaw 环境下的 Task Executor 执行指令。

> **继承**: 本文件继承 [base-executor.md](./base-executor.md) 的所有通用原则和流程。
> 本文档仅定义 OpenClaw 特定的工具语法和配置。

## 代理信息

| 属性 | 值 |
|------|-----|
| 代理名称 | OpenClaw |
| 配置文件 | `OPENCLAW.md`（项目根目录） |
| 工具调用语法 | 待确认 |

> **注意**: OpenClaw 的具体工具语法待确认后更新。目前使用通用模板。

## 核心工具

| 工具 | 用途 | Ralph Loop 场景 |
|------|------|-----------------|
| `read` | 读取文件 | 读取 features.json, task.md |
| `write` | 写入文件 | 创建代码文件 |
| `edit` | 编辑文件 | 修改 passes 字段 |
| `exec` | 执行命令 | git commit, npm test |
| `search` | 内容搜索 | 搜索代码模式 |

## 语法特点

- 待确认 OpenClaw 的具体语法格式
- 支持标准的文件操作
- 支持命令执行

## 执行流程映射

### 1. 获取上下文

```
exec: pwd
exec: git log --oneline -10
read: .ralph/current/features.json
read: .ralph/current/task.md
```

### 2. 阅读需求文档

```
如果功能有 requirement_refs：
read: requirements/xxx.md
```

### 3. 验证基础功能

```
使用浏览器工具测试基本功能
```

### 4. 实现功能

```
使用 edit 编辑代码
exec: npm run test
端到端验证
```

### 5. 更新状态

```
edit: .ralph/current/features.json
修改 "passes": false 为 "passes": true
```

### 6. 提交进度

```
exec: git add -A
exec: git commit -m "feat: 完成功能 XXX"
更新 progress.md
```

### 7. 输出完成信号

```
MISSION_COMPLETE
```

## 配置文件示例

在项目根目录创建 `OPENCLAW.md`：

```markdown
# Project Instructions

## Ralph Loop 任务调度

本项目使用 Ralph Loop 进行增量开发。

### 工作流程

1. read .ralph/current/features.json
2. 选择未完成的功能
3. 使用 edit 实现代码
4. exec npm run test
5. edit features.json 更新 passes
6. exec git commit
7. MISSION_COMPLETE

### 参考文档

- .ralph/agents/executor-openclaw.md - OpenClaw 执行指令
- .ralph/references/task-planner.md - 任务规划指南
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `OPENCLAW_SESSION` | OpenClaw 会话标识 |
| `RALPH_AGENT` | 强制指定 agent 类型 |

## 待确认事项

以下内容需要根据 OpenClaw 的实际实现进行更新：

1. **工具调用语法** - 确认具体的函数调用格式
2. **浏览器自动化** - 确认支持的浏览器工具
3. **扩展系统** - 确认是否支持插件扩展
4. **配置文件格式** - 确认配置文件的具体格式

---

> **贡献**: 如果您了解 OpenClaw 的具体实现，欢迎提交 PR 更新此文档。
