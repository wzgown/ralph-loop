# Ralph Loop v3.4

[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-orange?logo=anthropic)](https://docs.anthropic.com/claude-code)
[![GitHub](https://img.shields.io/badge/GitHub-wzgown/ralph--loop-blue?logo=github)](https://github.com/wzgown/ralph-loop)
[![Python](https://img.shields.io/badge/Python-3.8+-blue?logo=python)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Claude Code Skill** - 基于 Anthropic "Effective harnesses for long-running agents" 最佳实践的长时运行任务调度器。

## 这是什么？

Ralph Loop 帮助你管理长时运行的软件开发任务：

1. **规划任务** - AI 创建 `task.md` 和 `features.json`
2. **增量执行** - 每次只完成一个功能
3. **验证完成** - 使用测试客观验证
4. **记录进度** - 跨会话保持上下文

## 架构

```
~/.claude/skills/ralph-loop/    # 全局 Skill
├── core/ralph.py               # 调度器
├── templates/                  # 模板
└── references/                 # 参考文档

项目/.ralph/                     # 项目数据
├── current/
│   ├── task.md                 # 任务描述
│   ├── features.json           # 功能清单 ⬅️ 核心
│   └── progress.md             # 进度日志
├── tasks/                      # 历史归档
└── logs/                       # 日志
```

## 安装

```bash
# 远程安装（推荐）
curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash

# 本地安装
git clone https://github.com/wzgown/ralph-loop.git
cd /path/to/your/project
/path/to/ralph-loop/install.sh
```

## 命令

```bash
ralph                    # 运行当前任务
ralph --status           # 显示当前状态
ralph --features         # 显示功能清单
ralph --archive [name]   # 归档当前任务
```

## features.json

AI **只能修改 `passes` 字段**：

```json
[
  {
    "id": "F001",
    "description": "功能描述",
    "steps": ["测试步骤"],
    "verify_command": "npm test -- --grep 'xxx'",
    "passes": false
  }
]
```

## 工作流程

```
Task Planner (AI)          Task Executor (AI)
─────────────────          ──────────────────
理解需求                    读取 features.json
创建 task.md                选择未完成功能
创建 features.json          实现功能
                            验证测试
                            passes: true
                            Git commit
                            MISSION_COMPLETE
```

## 参考文档

- [SKILL.md](SKILL.md) - Skill 完整定义
- [references/task-planner.md](references/task-planner.md) - Task Planner 流程
- [references/features-format.md](references/features-format.md) - features.json 规范

## License

MIT
