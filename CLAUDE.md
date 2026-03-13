# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Ralph Loop 是一个 **Claude Code Skill**，基于 Anthropic "Effective harnesses for long-running agents" 最佳实践的长时运行任务调度器。

## v3.4 架构

**全局 Skill + 项目数据分离：**

```
~/.claude/skills/ralph-loop/    # 全局 Skill（脚本、模板）
├── SKILL.md                    # Skill 定义
├── core/                       # 核心脚本（全局共享）
│   ├── ralph.py                # 主调度器
│   ├── stop-hook.sh            # 验证脚本
│   └── agent-detector.sh       # 代理检测
├── agents/                     # 代理执行指令
├── templates/                  # 模板文件
└── references/                 # 参考文档

项目/.ralph/                     # 项目数据（每个项目独立）
├── current/                    # 当前任务
│   ├── task.md
│   ├── features.json           # 功能清单 ⬅️ 核心
│   └── progress.md
├── tasks/                      # 历史归档
└── logs/                       # 日志
```

## v3.4 职责分离

| AI 执行者 | Core 脚本 |
|-----------|-----------|
| 实现代码 | 验证 (stop-hook.sh) |
| 运行测试 | 更新 passes: true |
| 输出 MISSION_COMPLETE | Git commit |

**重要**：
- AI **无权**修改 features.json（由 Core 管理）
- AI **无权**执行 git commit（由 Core 管理）
- 验证通过后，Core 自动更新状态并提交代码

## 开发此仓库

```bash
# 安装到本仓库（用于测试）
./install.sh

# 测试命令
./ralph --status
./ralph --features
```

## 安装到其他项目

```bash
# 方式一：远程安装（推荐）
curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash

# 方式二：本地安装
/path/to/ralph-loop/install.sh
```

## 核心设计

### 两种角色

1. **Task Planner（任务规划者）**：用户描述需求时，AI 主动创建 task.md 和 features.json
2. **Task Executor（任务执行者）**：读取 features.json，实现单个功能，更新 passes: true

### 关键原则

| 问题 | 解决方案 |
|------|----------|
| AI 一次尝试做太多 | **增量工作** - 每次只做一个功能 |
| AI 过早宣布完成 | **Feature List (JSON)** - 结构化功能清单，客观验证 |
| AI 留下混乱状态 | **Clean State** - 每次会话结束确保代码可提交 |
| 上下文丢失 | **Progress File** - 记录已完成的工作 |

## features.json 规范

**AI 只能修改 `passes` 字段，不允许删除或修改其他内容。**

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

## 环境变量

```bash
RALPH_AGENT=claude             # 默认代理类型
RALPH_DATA_DIR=/path/.ralph    # 项目数据目录（自动设置）
MAX_FEATURE_RETRIES=3          # 单个功能最大重试次数
```

## 完成信号

Task Executor 必须在完成任务后单独一行输出：

```
MISSION_COMPLETE
```

## 参考文档

- [SKILL.md](SKILL.md) - Skill 完整定义
- [references/task-planner.md](references/task-planner.md) - Task Planner 详细流程
- [references/features-format.md](references/features-format.md) - features.json 格式规范
