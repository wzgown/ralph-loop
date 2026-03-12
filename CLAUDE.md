# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Ralph Loop 是一个长时运行任务调度器，基于 Anthropic "Effective harnesses for long-running agents" 最佳实践。核心解决 AI 代理在多上下文窗口中持续工作的挑战。

## 常用命令

### 开发与测试

```bash
# 运行当前任务
./ralph

# 指定代理类型运行
./ralph --agent claude    # Claude Code（默认）
./ralph --agent codex     # Codex CLI
./ralph --agent gemini    # Gemini CLI

# 任务管理
./ralph --new              # 创建空白任务模板
./ralph --init [file]     # 初始化新任务
./ralph --status          # 显示当前状态
./ralph --features       # 显示功能清单
./ralph --tasks          # 列出所有任务

# 队列管理
./ralph --queue          # 显示任务队列
./ralph --enqueue <file> # 添加任务到队列
./ralph --next           # 获取下一个任务

# 维护
./ralph --archive [name] # 归档当前任务
./ralph --clean          # 检查工作区状态
```

### 安装到项目

```bash
# 本地安装
./install.sh --agent claude

# 远程安装（一键安装）
curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash -s -- --agent claude
```

## 核心架构

### 两种角色

1. **Task Planner（任务规划者）**：理解用户需求，创建 task.md 和 features.json
2. **Task Executor（任务执行者）**：读取 features.json，实现单个功能，更新 passes: true

### 目录结构

```
.ralph/
├── scripts/
│   ├── ralph           # Shell wrapper
│   ├── ralph.py        # Python 主调度器
│   └── stop-hook.sh    # 验证脚本
├── skills/             # 代理执行指令
│   ├── executor-claude.md
│   ├── executor-codex.md
│   └── executor-gemini.md
├── current/            # 当前任务
│   ├── task.md         # 任务描述
│   ├── features.json   # 功能清单（核心）
│   ├── requirements/   # 需求文档（可选）
│   └── progress.md     # 进度日志
├── queue/              # 任务队列
├── tasks/              # 历史任务归档
├── logs/               # 循环日志
└── references/         # 参考文档
```

### 关键设计原则

| 问题 | 解决方案 |
|------|----------|
| AI 一次尝试做太多 | **增量工作** - 每次只做一个功能 |
| AI 过早宣布完成 | **Feature List (JSON)** - 结构化功能清单，客观验证 |
| AI 留下混乱状态 | **Clean State** - 每次会话结束确保代码可提交 |
| AI 未正确测试 | **端到端验证** - 使用浏览器自动化工具 |
| 上下文丢失 | **Progress File** - 记录已完成的工作 |

## features.json 规范

### AI 行为约束

> **重要**：AI 只能修改 `passes` 字段，不允许删除或修改 features.json 中的其他内容。

### 功能拆分原则

- **粒度适中**：每个功能 1-2 小时可完成
- **可验证**：必须有明确的 `verify_command`
- **独立性**：功能之间减少依赖

### 字段说明

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

## 环境变量

```bash
RALPH_AGENT=claude             # 默认代理类型
MAX_FEATURE_RETRIES=3          # 单个功能最大重试次数
CLAUDE_TIMEOUT=1800            # 单次执行超时（秒）
```

## 完成信号

Task Executor 必须在完成任务后单独一行输出：

```
MISSION_COMPLETE
```

## 参考文档

- [references/task-planner.md](references/task-planner.md) - Task Planner 详细流程
- [references/features-format.md](references/features-format.md) - features.json 格式规范
- [skills/executor-claude.md](skills/executor-claude.md) - Claude Code 执行指令
