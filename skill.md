# Ralph Loop v2.0 Skill

基于 Anthropic "Effective harnesses for long-running agents" 最佳实践的长时运行任务调度器。

## 概述

Ralph Loop 解决 AI 代理在多上下文窗口中持续工作的挑战：

| 问题 | 解决方案 |
|------|----------|
| AI 一次尝试做太多 | **增量工作** - 每次只做一个功能 |
| AI 过早宣布完成 | **Feature List (JSON)** - 结构化功能清单，客观验证 |
| AI 留下混乱状态 | **Clean State** - 每次会话结束确保代码可提交 |
| AI 未正确测试 | **端到端验证** - 使用浏览器自动化工具 |
| 上下文丢失 | **Progress File** - 记录已完成的工作 |

---

## 触发条件

当用户：
1. 描述一个复杂的开发需求，需要多个步骤完成
2. 请求创建开发任务或功能清单
3. 提到 "ralph"、"ralph loop"、".ralph" 目录
4. 需要将模糊需求转换为结构化任务
5. 运行 `./ralph` 或 `.ralph/scripts/run-ralph.sh`

---

## AI 的两种角色

### 角色 1: Task Planner（任务规划者）

帮助用户将需求转换为 Ralph Loop 标准格式：

**输入**：用户的自然语言需求描述

**输出**：
- `task.md` - 任务描述
- `features.json` - 结构化功能清单（核心）
- `init.sh` - 环境初始化脚本
- `verify.sh` - 验证脚本

### 角色 2: Task Executor（任务执行者）

由 `run-ralph.sh` 调用，增量式完成功能开发：

**输入**：`features.json` 中的待完成功能

**输出**：
- 实现代码
- `passes: true` 更新
- Git commit
- `MISSION_COMPLETE` 信号

---

## 目录结构

```
.ralph/
├── scripts/
│   ├── run-ralph.sh      # 主调度器
│   └── stop-hook.sh      # 验证脚本
├── templates/            # 模板文件
├── current/              # 当前任务（工作目录）
│   ├── task.md           # 任务描述
│   ├── features.json     # 功能清单 ⬅️ 核心
│   ├── progress.md       # 进度日志
│   ├── init.sh           # 启动脚本
│   └── verify.sh         # 验证脚本
├── queue/                # 任务队列
│   └── task-queue.json
├── tasks/                # 历史任务归档
└── logs/                 # 循环日志
```

---

## 核心：features.json 格式

```json
{
  "task_id": "F-20260308-001",
  "task_name": "用户认证系统",
  "created_at": "2026-03-08T10:00:00+08:00",
  "features": [
    {
      "id": "F001",
      "category": "functional",
      "description": "用户可以使用邮箱和密码登录",
      "priority": "high",
      "steps": [
        "打开登录页面 /login",
        "输入邮箱 test@example.com",
        "输入密码 password123",
        "点击登录按钮",
        "验证跳转到首页并显示用户名"
      ],
      "verify_command": "npm run test:e2e -- --grep 'login'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    }
  ]
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 功能唯一标识（F001, F002...） |
| `category` | string | 分类：functional, ui, api, bugfix |
| `description` | string | 简洁的功能描述 |
| `priority` | string | 优先级：high, medium, low |
| `steps` | array | 可执行的测试步骤 |
| `verify_command` | string | 自动化验证命令 |
| `passes` | boolean | **AI 只能修改此字段** |
| `completed_at` | string | 完成时间戳 |
| `notes` | string | 备注 |

---

## Task Planner 工作流程

当用户描述需求时，按以下步骤创建任务：

### 步骤 1：理解需求

1. 分析用户的自然语言描述
2. 识别主要功能点
3. 确认技术约束和成功标准

### 步骤 2：创建 task.md

```markdown
# 任务：[简短描述]

## 背景

[为什么需要这个功能，业务上下文]

## 成功标准

- [ ] 标准 1（可验证）
- [ ] 标准 2（可验证）

## 实现计划

- [ ] **T1**: 第一步
- [ ] **T2**: 第二步

## 约束

**必须：**
- [技术约束]
- [业务约束]

**禁止：**
- [不允许的做法]

## 完成信号

MISSION_COMPLETE
```

### 步骤 3：创建 features.json

**功能拆分原则：**

1. **粒度适中** - 每个功能应在 1-2 小时内可完成
2. **可验证** - 每个功能必须有明确的 `verify_command`
3. **独立性** - 功能之间尽量减少依赖
4. **优先级** - 高优先级功能排在前面

**错误示例**（粒度太粗）：
```json
{
  "id": "F001",
  "description": "实现完整的用户认证系统",
  "verify_command": "npm test"
}
```

**正确示例**（合理拆分）：
```json
[
  { "id": "F001", "description": "登录页面 UI", "verify_command": "npm run test:e2e -- --grep 'login UI'" },
  { "id": "F002", "description": "登录 API 集成", "verify_command": "npm run test:e2e -- --grep 'login API'" },
  { "id": "F003", "description": "登录错误处理", "verify_command": "npm run test:e2e -- --grep 'login error'" },
  { "id": "F004", "description": "会话持久化", "verify_command": "npm run test:e2e -- --grep 'session'" }
]
```

### 步骤 4：创建 init.sh

```bash
#!/bin/bash
# 任务初始化脚本

echo "=== 初始化任务环境 ==="

# 根据项目类型添加初始化逻辑
# 例如：启动开发服务器、运行数据库迁移等

echo "✅ 环境初始化完成"
```

### 步骤 5：创建 verify.sh

```bash
#!/bin/bash
set -e
echo "=== 验证功能 ==="

# 检查代码编译
# 运行测试
# 其他验证逻辑

echo "✅ 验证通过"
```

---

## Task Executor 工作流程

由 `run-ralph.sh` 自动调用，AI 必须严格遵守：

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
   - pwd
   - git log --oneline -10
   - 读取 features.json

2. 选择第一个 passes: false 的功能

3. 验证基础功能
   - 运行 init.sh 启动开发服务器
   - 使用浏览器自动化测试基本功能
   - 发现现有 bug 先修复

4. 实现单个功能
   - 编写代码
   - 运行测试
   - 端到端验证

5. 更新状态
   - 只修改 passes 字段为 true
   - 不要删除或修改其他内容

6. 提交进度
   - git add -A
   - git commit -m "feat: 完成功能 XXX"

7. 更新 progress.md
   - 添加会话记录

8. 输出完成信号
   MISSION_COMPLETE
```

### 禁止事项

- ❌ 不要一次实现多个功能
- ❌ 不要删除或修改 features.json 中的测试步骤
- ❌ 不要在未测试的情况下标记 passes: true
- ❌ 不要留下未提交的代码
- ❌ 不要修改已跳过的功能（达到最大重试次数）

---

## 验证机制 (Stop Hook)

每次 AI 执行后，`stop-hook.sh` 自动运行验证：

1. **检查 MISSION_COMPLETE** - AI 必须输出此信号
2. **检查 Git 状态** - 警告未提交的更改
3. **执行 verify_command** - 对所有 `passes: true` 的功能运行验证命令

如果验证失败：
- 功能重试计数 +1
- 失败日志追加到 task.md
- 达到 `MAX_FEATURE_RETRIES=3` 次后跳过该功能

---

## 命令参考

```bash
# 任务管理
ralph                          # 运行当前任务（Coding Agent 模式）
ralph --init [file]            # 初始化新任务
ralph --new                    # 创建空白任务
ralph --status                 # 显示当前状态
ralph --features               # 显示功能清单
ralph --progress               # 显示进度日志
ralph --tasks                  # 列出所有任务

# 队列管理
ralph --queue                  # 显示任务队列
ralph --enqueue <file>         # 添加任务到队列
ralph --dequeue <id>           # 从队列移除任务
ralph --next                   # 获取下一个任务

# 维护
ralph --archive [name]         # 归档当前任务
ralph --reset                  # 重置失败日志
ralph --clean                  # 检查工作区状态
ralph --help                   # 显示帮助
```

### 环境变量

```bash
MAX_FEATURE_RETRIES=3    # 单个功能最大重试次数
CLAUDE_TIMEOUT=1800      # 单次执行超时（秒）
DELAY_SECONDS=2          # 循环间隔（秒）
```

---

## 完整示例

### 用户输入

> 我需要实现一个用户个人资料编辑功能，用户可以修改头像、昵称、个人简介，还要能预览更改

### AI 响应（Task Planner）

我来帮你创建这个任务。首先创建 task.md：

```markdown
# 任务：用户个人资料编辑功能

## 背景

用户需要能够编辑自己的个人资料，包括头像、昵称和个人简介，并能在保存前预览更改。

## 成功标准

- [ ] 用户可以上传并裁剪头像
- [ ] 用户可以修改昵称（2-20字符）
- [ ] 用户可以编辑个人简介（最多500字）
- [ ] 预览功能实时显示更改
- [ ] 保存后数据持久化

## 实现计划

- [ ] **T1**: 创建个人资料编辑页面 UI
- [ ] **T2**: 实现头像上传和裁剪
- [ ] **T3**: 实现表单验证
- [ ] **T4**: 实现预览功能
- [ ] **T5**: 实现 API 集成

## 约束

**必须：**
- 头像大小限制 2MB
- 昵称不能包含特殊字符
- 使用现有的认证系统

**禁止：**
- 不允许上传非图片文件
- 不允许修改其他用户的资料

## 完成信号

MISSION_COMPLETE
```

然后创建 features.json：

```json
{
  "task_id": "F-20260308-002",
  "task_name": "用户个人资料编辑功能",
  "created_at": "2026-03-08T14:00:00+08:00",
  "features": [
    {
      "id": "F001",
      "category": "ui",
      "description": "个人资料编辑页面基础布局",
      "priority": "high",
      "steps": [
        "访问 /profile/edit",
        "验证页面包含头像、昵称、简介输入区域",
        "验证有保存和取消按钮"
      ],
      "verify_command": "npm run test:e2e -- --grep 'profile edit page'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    },
    {
      "id": "F002",
      "category": "functional",
      "description": "头像上传和裁剪功能",
      "priority": "high",
      "steps": [
        "点击头像区域",
        "选择图片文件（< 2MB）",
        "使用裁剪器调整",
        "验证预览更新"
      ],
      "verify_command": "npm run test:e2e -- --grep 'avatar upload'",
      "passes": false,
      "completed_at": null,
      "notes": "使用 Cropper.js"
    },
    {
      "id": "F003",
      "category": "functional",
      "description": "表单验证",
      "priority": "high",
      "steps": [
        "输入 1 字符昵称，验证错误提示",
        "输入 21 字符昵称，验证错误提示",
        "输入 501 字符简介，验证错误提示",
        "输入有效数据，验证通过"
      ],
      "verify_command": "npm run test:e2e -- --grep 'profile validation'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    },
    {
      "id": "F004",
      "category": "functional",
      "description": "实时预览功能",
      "priority": "medium",
      "steps": [
        "修改昵称，验证预览区实时更新",
        "修改简介，验证预览区实时更新",
        "更换头像，验证预览区实时更新"
      ],
      "verify_command": "npm run test:e2e -- --grep 'profile preview'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    },
    {
      "id": "F005",
      "category": "api",
      "description": "保存资料 API 集成",
      "priority": "high",
      "steps": [
        "修改所有字段",
        "点击保存",
        "验证 API 请求正确",
        "验证成功提示",
        "刷新页面验证数据持久化"
      ],
      "verify_command": "npm run test:e2e -- --grep 'profile save'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    }
  ]
}
```

现在可以运行 `./ralph --init` 初始化任务，然后 `./ralph` 开始执行。

---

## 安装

```bash
# 方式一：Git clone
git clone https://github.com/wzgown/ralph-loop.git
cd /path/to/your/project
/path/to/ralph-loop/install.sh

# 方式二：一键安装
curl -fsSL https://raw.githubusercontent.com/wzgown/ralph-loop/main/install.sh | bash
```

安装后：
- 项目脚手架 → `.ralph/`
- Claude Code Skill → `~/.claude/skills/ralph-loop/`
