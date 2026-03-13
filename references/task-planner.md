# Task Planner 流程

Task Planner 负责将用户需求组织成 Ralph Loop 标准格式。

## 核心理念

**Task Planner 是组织者，不是创建者。**

- 需求文档通常已存在于项目中（如 `docs/req/`、`specs/` 等）
- Task Planner 的职责是**组织**这些需求，让执行阶段可以方便查阅
- 只有在需求不明确时，才需要补充或澄清

## 工作流程

### 1. 理解需求

1. 分析用户的自然语言描述
2. 识别主要功能点
3. 确认技术约束和成功标准

### 2. 组织需求文档

**如果需求文档已存在**：
- 在 task.md 中引用路径
- 如有必要，复制到 `.ralph/current/requirements/` 方便执行阶段查阅

**如果需求分散或不够清晰**：
- 整理现有需求片段
- 补充缺失的业务规则
- 不要重新发明轮子

### 3. 创建 task.md

```markdown
# 任务：[简短描述]

## 背景

[为什么需要这个功能，业务上下文]

## 需求文档

| 文档 | 路径 | 说明 |
|------|------|------|
| 认证需求 | `requirements/auth.md` | 用户认证业务规则 |

> **注意**：执行功能时如需了解业务规则，请查阅相关需求文档。

## 成功标准

- [ ] 标准 1（可验证）
- [ ] 标准 2（可验证）

## 约束

**必须：**
- [技术约束]

**禁止：**
- [不允许的做法]
```

### 4. 创建 features.json

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

## 输出文件

| 文件 | 用途 |
|------|------|
| `task.md` | 任务背景、需求引用、成功标准 |
| `features.json` | 结构化功能清单（核心） |
| `requirements/` | 需求文档（按需组织） |

## 进度记录

进度由 `progress.md` 记录，**不在 task.md 中追加任何内容**。
