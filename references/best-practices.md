# Ralph Loop 最佳实践

本文档提供功能拆分、验证命令和任务规划的最佳实践指南。

## 功能拆分原则

### 核心原则

| 原则 | 说明 | 反例 |
|------|------|------|
| **粒度适中** | 每个功能 1-2 小时可完成 | "实现完整的用户认证系统" |
| **可验证** | 必须有明确的 verify_command | "优化代码质量" |
| **独立性** | 功能之间减少依赖 | F002 依赖 F001 的内部实现 |
| **原子性** | 一个功能做一件事 | "添加登录和注册功能" |

### 功能拆分示例

#### ❌ 错误示例：过于粗粒度

```json
{
  "id": "F001",
  "description": "实现完整的用户认证系统",
  "verify_command": "npm test",
  "passes": false
}
```

问题：
- 太大，无法在一次迭代中完成
- 验证命令不具体
- 难以追踪进度

#### ✅ 正确示例：合理拆分

```json
[
  {
    "id": "F001",
    "description": "创建登录页面 UI（邮箱/密码表单）",
    "steps": [
      "访问 /login 页面",
      "检查邮箱和密码输入框存在",
      "检查登录按钮存在"
    ],
    "verify_command": "npm run test:e2e -- --grep 'login page renders'",
    "passes": false
  },
  {
    "id": "F002",
    "description": "实现登录 API 集成（调用 /api/auth/login）",
    "requirement_refs": ["requirements/auth.md#api-spec"],
    "steps": [
      "填写有效邮箱和密码",
      "点击登录按钮",
      "验证成功后跳转到首页"
    ],
    "verify_command": "npm run test:e2e -- --grep 'login with valid credentials'",
    "passes": false
  },
  {
    "id": "F003",
    "description": "添加登录错误处理（无效凭据、网络错误）",
    "requirement_refs": ["requirements/auth.md#error-handling"],
    "steps": [
      "填写无效密码",
      "点击登录按钮",
      "验证显示错误消息"
    ],
    "verify_command": "npm run test:e2e -- --grep 'login error handling'",
    "passes": false
  },
  {
    "id": "F004",
    "description": "实现会话持久化（localStorage 存储 token）",
    "steps": [
      "登录成功后刷新页面",
      "验证用户仍保持登录状态"
    ],
    "verify_command": "npm run test:e2e -- --grep 'session persistence'",
    "passes": false
  }
]
```

## 验证命令最佳实践

### 验证命令类型

| 类型 | 适用场景 | 示例 |
|------|----------|------|
| **单元测试** | 纯逻辑、工具函数 | `npm run test:unit -- --grep 'utils/format'` |
| **集成测试** | API、数据库交互 | `npm run test:integration -- --grep 'api/users'` |
| **E2E 测试** | UI、用户流程 | `npm run test:e2e -- --grep 'login flow'` |
| **类型检查** | TypeScript 项目 | `npm run typecheck` |
| **Lint 检查** | 代码规范 | `npm run lint` |
| **构建检查** | 编译通过 | `npm run build` |

### 验证命令原则

1. **确定性** - 相同输入产生相同结果
2. **快速** - 最好在 30 秒内完成
3. **隔离** - 不依赖外部服务状态
4. **清晰** - 测试名称描述清楚

#### ❌ 错误示例

```json
{
  "verify_command": "npm test"
}
```

问题：
- 运行所有测试，太慢
- 不清楚哪个测试与当前功能相关

#### ✅ 正确示例

```json
{
  "verify_command": "npm run test:e2e -- --grep 'user can login with valid credentials'"
}
```

### 验证命令组合

对于需要多种验证的功能：

```json
{
  "verify_command": "npm run typecheck && npm run test:unit -- --grep 'auth' && npm run test:e2e -- --grep 'login'"
}
```

## 需求文档引用

### 何时创建需求文档

| 场景 | 建议 |
|------|------|
| 简单 CRUD | 不需要，在 task.md 中描述 |
| 业务规则复杂 | 创建 requirements/xxx.md |
| 涉及第三方 API | 创建，记录 API 规范 |
| 有合规要求 | 创建，记录合规检查点 |

### 需求文档格式

```markdown
# 用户认证需求

## API 规范 {#api-spec}

### 登录接口

- **端点**: `POST /api/auth/login`
- **请求体**:
  ```json
  {
    "email": "user@example.com",
    "password": "password123"
  }
  ```
- **成功响应** (200):
  ```json
  {
    "token": "jwt_token_here",
    "user": { "id": 1, "email": "user@example.com" }
  }
  ```
- **失败响应** (401):
  ```json
  {
    "error": "Invalid credentials"
  }
  ```

## 错误处理 {#error-handling}

| 错误类型 | HTTP 状态码 | 错误消息 | UI 行为 |
|----------|-------------|----------|---------|
| 无效密码 | 401 | "Invalid credentials" | 显示红色错误提示 |
| 账户锁定 | 423 | "Account locked" | 跳转到解锁页面 |
| 网络错误 | - | - | 显示重试按钮 |

## 会话管理 {#session}

- Token 存储在 localStorage
- Token 有效期 7 天
- 过期后自动跳转登录页
```

### 引用格式

```json
{
  "id": "F002",
  "description": "实现登录 API 集成",
  "requirement_refs": [
    "requirements/auth.md#api-spec",
    "requirements/auth.md#error-handling"
  ]
}
```

## 任务描述最佳实践

### task.md 结构

```markdown
# 任务标题

## 背景

描述为什么需要这个功能，解决什么问题。

## 需求文档

- [requirements/auth.md](./requirements/auth.md) - 认证需求详细说明

## 成功标准

- [ ] 用户可以使用邮箱密码登录
- [ ] 无效凭据显示错误消息
- [ ] 登录状态在页面刷新后保持

## 实现计划

1. F001: 登录页面 UI
2. F002: 登录 API 集成
3. F003: 错误处理
4. F004: 会话持久化

## 约束

- 必须使用现有的 API 端点
- 不能修改数据库 schema
- 兼容 IE11
```

## 常见问题

### Q: 功能太大，无法在一次迭代中完成怎么办？

A: 继续拆分。每个功能应该能在 1-2 小时内完成。

### Q: 功能之间有依赖怎么办？

A:
1. 尽量减少依赖
2. 必要的依赖按顺序排列
3. 在 task.md 中说明依赖关系

### Q: 如何验证 UI 变更？

A: 使用 E2E 测试或浏览器自动化工具：
- Claude Code: `mcp__chrome-devtools__*`
- Gemini CLI: `browser_agent`
- Codex CLI: 内置浏览器集成

### Q: 验证命令失败了怎么办？

A:
1. 检查错误日志
2. 修复问题
3. 重新运行验证命令
4. 如果达到重试上限，功能会被跳过

## 检查清单

创建 features.json 前，确认：

- [ ] 每个功能 1-2 小时可完成
- [ ] 每个功能有明确的 verify_command
- [ ] 功能之间依赖最小化
- [ ] 复杂业务规则有需求文档
- [ ] verify_command 是确定性的
- [ ] 成功标准清晰可验证
