# Task Planner 详细流程

Task Planner 负责将用户的自然语言需求转换为 Ralph Loop 标准格式。

## 创建任务的三种方式

### 方式一：直接向 AI 描述需求（推荐）

用户可以直接用自然语言描述需求，AI 会自动创建完整的任务文件：

```
用户：我需要实现一个用户个人资料编辑功能，用户可以修改头像、昵称、个人简介，还要能预览更改

AI：我来帮你创建这个任务...

    1. 创建 .ralph/current/task.md
    2. 创建 .ralph/current/features.json（5 个功能）
    3. 创建 .ralph/current/init.sh
    4. 创建 .ralph/current/verify.sh

    任务已创建。运行 ./ralph 开始执行。
```

### 方式二：使用命令行模板

```bash
./ralph --new                    # 创建空白任务模板
vim .ralph/current/task.md       # 编辑任务描述
./ralph --init                   # 初始化任务环境
```

### 方式三：从现有文件初始化

```bash
./ralph --init path/to/task.md   # 从现有任务文件初始化
```

## 步骤详解

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
