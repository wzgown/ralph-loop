# features.json 格式规范

features.json 是 Ralph Loop 的核心文件，定义了任务的功能清单。

## 完整格式

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

## 字段说明

### 任务级别字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `task_id` | string | 是 | 任务唯一标识 |
| `task_name` | string | 是 | 任务名称 |
| `created_at` | string | 是 | 创建时间（ISO 8601） |
| `requirements_dir` | string | 否 | 需求文档目录路径（默认 `requirements/`） |
| `features` | array | 是 | 功能列表 |

### 功能级别字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | 是 | 功能唯一标识（F001, F002...） |
| `category` | string | 否 | 分类：functional, ui, api, bugfix |
| `description` | string | 是 | 简洁的功能描述 |
| `priority` | string | 否 | 优先级：high, medium, low |
| `requirement_refs` | array | 否 | 需求文档引用列表（如 `["requirements/auth.md#login"]`） |
| `steps` | array | 是 | 可执行的测试步骤 |
| `verify_command` | string | 是 | 自动化验证命令 |
| `passes` | boolean | 是 | 是否通过（**AI 只能修改此字段**） |
| `completed_at` | string | 否 | 完成时间戳 |
| `notes` | string | 否 | 备注 |

## AI 行为约束

> ⚠️ **重要**：AI 只能修改 `passes` 字段，不允许删除或修改其他内容。

```
It is unacceptable to remove or edit tests because this could lead to missing or buggy functionality.
```

## 功能拆分最佳实践

### 粒度适中

每个功能应在 1-2 小时内可完成。

**❌ 错误**：粒度太粗
```json
{
  "id": "F001",
  "description": "实现完整的用户认证系统",
  "verify_command": "npm test"
}
```

**✅ 正确**：合理拆分
```json
[
  { "id": "F001", "description": "登录页面 UI" },
  { "id": "F002", "description": "登录 API 集成" },
  { "id": "F003", "description": "登录错误处理" },
  { "id": "F004", "description": "会话持久化" }
]
```

### 可验证

每个功能必须有明确的 `verify_command`。

```json
{
  "verify_command": "npm run test:e2e -- --grep 'profile edit page'"
}
```

### 独立性

功能之间尽量减少依赖，按优先级排序。

```json
[
  { "id": "F001", "priority": "high", "description": "基础布局" },
  { "id": "F002", "priority": "high", "description": "核心功能" },
  { "id": "F003", "priority": "medium", "description": "增强功能" }
]
```

## 为什么用 JSON 而不是 Markdown？

根据 Anthropic 研究，AI 模型更不容易不当地修改或覆盖 JSON 文件，相比 Markdown 文件。
