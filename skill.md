# Ralph Loop Skill

Ralph Loop 是一个长时运行任务调度器，基于 Anthropic "Effective harnesses for long-running agents" 最佳实践。

## 触发条件

当用户需要：
- 运行复杂的多步骤开发任务
- 管理多个功能的增量实现
- 跟踪 AI 代理的长期工作进度
- 确保代码质量和干净状态

## 核心原则

1. **增量工作** - 每次只完成一个功能
2. **结构化清单** - 使用 JSON 格式的功能清单
3. **干净状态** - 每次会话结束确保代码可提交
4. **端到端验证** - 使用浏览器自动化测试
5. **进度追踪** - 记录已完成的工作

## 使用方法

### 初始化

```bash
# 在项目根目录运行
./.ralph/scripts/run-ralph.sh --init path/to/task.md
```

### 运行任务

```bash
./.ralph/scripts/run-ralph.sh
```

### 查看状态

```bash
./.ralph/scripts/run-ralph.sh --status
./.ralph/scripts/run-ralph.sh --features
```

## 工作流程

1. **Initializer Agent 模式** (`--init`)
   - 设置环境
   - 创建 `features.json` 功能清单
   - 创建 `init.sh` 启动脚本
   - 创建 `progress.md` 进度日志

2. **Coding Agent 模式** (默认)
   - 读取 `features.json`，选择未完成功能
   - 实现单个功能
   - 端到端测试验证
   - 更新 `passes: true`
   - Git commit + 更新 `progress.md`
   - 输出 `MISSION_COMPLETE`

## 目录结构

```
.ralph/
├── scripts/
│   ├── run-ralph.sh      # 主调度器
│   └── stop-hook.sh      # 验证执行
├── templates/            # 模板文件
├── current/              # 当前任务
│   ├── task.md           # 任务描述
│   ├── features.json     # 功能清单 (核心)
│   ├── progress.md       # 进度日志
│   ├── init.sh           # 启动脚本
│   └── verify.sh         # 验证脚本
├── queue/                # 任务队列
├── tasks/                # 历史任务归档
└── logs/                 # 循环日志
```

## 功能清单格式

```json
{
  "task_id": "F-20260306-001",
  "task_name": "任务名称",
  "created_at": "2026-03-06T10:00:00+08:00",
  "features": [
    {
      "id": "F001",
      "category": "functional",
      "description": "功能描述",
      "priority": "high",
      "steps": ["步骤1", "步骤2"],
      "verify_command": "npm run test",
      "passes": false,
      "completed_at": null,
      "notes": ""
    }
  ]
}
```

## 重要约束

- **AI 只能修改 `passes` 字段**，不允许删除或修改其他内容
- **每次只做一个功能**，避免一次尝试太多
- **必须端到端验证**，不能仅依赖单元测试
- **必须输出 `MISSION_COMPLETE`** 信号表示完成

## 命令参考

```bash
ralph                          # 运行当前任务
ralph --init [file]            # 初始化新任务
ralph --new                    # 创建空白任务
ralph --status                 # 显示状态
ralph --features               # 显示功能清单
ralph --progress               # 显示进度日志
ralph --tasks                  # 列出所有任务
ralph --queue                  # 显示任务队列
ralph --enqueue <file>         # 添加任务到队列
ralph --archive [name]         # 归档当前任务
ralph --clean                  # 检查工作区状态
ralph --help                   # 显示帮助
```
