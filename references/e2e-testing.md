# 端到端测试指南

本文档提供各 AI Agent 的端到端测试方法和工具使用指南。

## 概述

端到端（E2E）测试是 Ralph Loop 验证流程的关键环节。每个功能完成后，都应该通过 E2E 测试验证其行为符合预期。

## 测试策略

### 测试金字塔

```
        /\
       /  \      E2E Tests (用户流程)
      /----\     - 登录流程
     /      \    - 购物车流程
    /--------\   - 支付流程
   /          \
  /------------\ Integration Tests (API + DB)
 /              \ - API 端点测试
/----------------\ - 数据库操作测试
  Unit Tests       - 函数单元测试
```

### Ralph Loop 中的测试

| 测试类型 | 在 features.json 中的位置 | 运行时机 |
|----------|---------------------------|----------|
| 单元测试 | `verify_command` | 功能完成后 |
| 集成测试 | `verify_command` | 功能完成后 |
| E2E 测试 | `verify_command` 或浏览器自动化 | 功能完成后 |

## Claude Code 浏览器自动化

### 可用工具

| 工具 | 用途 | 示例场景 |
|------|------|----------|
| `mcp__chrome-devtools__navigate_page` | 导航到 URL | 打开登录页面 |
| `mcp__chrome-devtools__take_snapshot` | 获取页面快照 | 检查页面结构 |
| `mcp__chrome-devtools__click` | 点击元素 | 点击登录按钮 |
| `mcp__chrome-devtools__fill` | 填写表单 | 输入邮箱密码 |
| `mcp__chrome-devtools__type_text` | 输入文本 | 输入搜索关键词 |
| `mcp__chrome-devtools__take_screenshot` | 截图 | 视觉验证 |
| `mcp__chrome-devtools__evaluate_script` | 执行 JS | 获取页面状态 |
| `mcp__chrome-devtools__wait_for` | 等待元素 | 等待加载完成 |

### 测试流程示例

```
1. 导航到页面
   mcp__chrome-devtools__navigate_page
   - type: url
   - url: http://localhost:3000/login

2. 获取页面快照，检查结构
   mcp__chrome-devtools__take_snapshot

3. 填写登录表单
   mcp__chrome-devtools__fill
   - uid: email-input
   - value: user@example.com

   mcp__chrome-devtools__fill
   - uid: password-input
   - value: password123

4. 点击登录按钮
   mcp__chrome-devtools__click
   - uid: login-button

5. 等待导航完成
   mcp__chrome-devtools__wait_for
   - text: ["Welcome"]

6. 截图验证
   mcp__chrome-devtools__take_screenshot
```

### 最佳实践

1. **使用快照而非截图** - 快照提供结构化数据，更可靠
2. **使用 wait_for** - 等待异步操作完成
3. **检查关键元素** - 验证核心功能而非视觉细节
4. **处理超时** - 设置合理的超时时间

## Codex CLI 浏览器集成

### 内置浏览器支持

Codex CLI 内置浏览器自动化功能，可以通过自然语言描述测试场景。

### 测试流程示例

```
1. 打开 http://localhost:3000/login

2. 在邮箱输入框输入 user@example.com

3. 在密码输入框输入 password123

4. 点击登录按钮

5. 等待页面跳转到首页

6. 检查是否显示欢迎消息
```

### 注意事项

- Codex CLI 会自动处理等待和重试
- 使用清晰、具体的描述
- 避免模糊的指令

## Gemini CLI 浏览器自动化

### browser_agent 工具

Gemini CLI 提供 `browser_agent` 扩展工具用于浏览器自动化。

### 测试流程示例

```
1. 激活 browser_agent

2. 导航到测试页面
   browser_agent: navigate to http://localhost:3000/login

3. 填写表单
   browser_agent: fill email field with user@example.com
   browser_agent: fill password field with password123

4. 执行操作
   browser_agent: click login button

5. 验证结果
   browser_agent: check page contains "Welcome"
```

### 其他相关工具

| 工具 | 用途 |
|------|------|
| `web_fetch` | 获取网页内容 |
| `google_web_search` | Google 搜索 |

## OpenClaw 浏览器支持

> **待确认**: OpenClaw 的浏览器自动化工具待确认后更新。

## E2E 测试最佳实践

### 测试隔离

```javascript
// ❌ 错误：依赖外部状态
it('should login', async () => {
  // 假设用户已存在
  await login('existing@example.com', 'password');
});

// ✅ 正确：创建测试数据
it('should login', async () => {
  await createTestUser('test@example.com', 'password');
  await login('test@example.com', 'password');
});
```

### 等待策略

```
❌ 错误：硬编码等待
sleep(2000)

✅ 正确：等待条件
wait_for(text: ["Welcome"])
wait_for(selector: ".loading", hidden: true)
```

### 选择器策略

| 策略 | 优先级 | 示例 |
|------|--------|------|
| 角色选择器 | 高 | `getByRole('button', { name: 'Login' })` |
| 文本选择器 | 高 | `getByText('Welcome')` |
| 测试 ID | 中 | `data-testid="login-button"` |
| CSS 选择器 | 低 | `.login-form button` |

### 错误处理

```
1. 捕获错误截图
   mcp__chrome-devtools__take_screenshot

2. 记录错误信息
   更新 progress.md 记录失败原因

3. 分析错误
   - 元素未找到？检查选择器
   - 超时？增加等待时间
   - 断言失败？检查预期值

4. 修复并重试
```

## 常见测试场景

### 登录流程

```
1. 导航到登录页
2. 检查表单元素存在
3. 填写邮箱和密码
4. 点击登录按钮
5. 等待导航
6. 验证登录成功（显示用户名或跳转到首页）
```

### 表单提交

```
1. 导航到表单页
2. 填写必填字段
3. 点击提交按钮
4. 等待响应
5. 验证成功消息或错误提示
```

### 列表操作

```
1. 导航到列表页
2. 检查列表项数量
3. 点击某一项
4. 验证详情页显示
5. 返回列表
```

### 搜索功能

```
1. 导航到搜索页
2. 输入搜索关键词
3. 点击搜索按钮或按回车
4. 等待结果加载
5. 验证搜索结果
```

## 调试技巧

### 截图调试

```
在关键步骤截图：
- 页面加载后
- 表单填写后
- 点击操作后
- 出现错误时
```

### 快照分析

```
使用 take_snapshot 获取页面结构：
- 检查元素是否存在
- 检查元素属性
- 检查文本内容
```

### 控制台日志

```
使用 evaluate_script 获取控制台日志：
mcp__chrome-devtools__evaluate_script
- function: () => {
    return {
      url: window.location.href,
      errors: window.__errors || []
    }
  }
```

## 测试环境

### 本地开发环境

```bash
# 启动开发服务器
npm run dev

# 运行 E2E 测试
npm run test:e2e
```

### CI 环境

```yaml
# GitHub Actions 示例
- name: Run E2E tests
  run: npm run test:e2e
  env:
    CI: true
    BASE_URL: http://localhost:3000
```

## 检查清单

E2E 测试前确认：

- [ ] 开发服务器已启动
- [ ] 测试数据库已准备
- [ ] 测试账号已创建
- [ ] 浏览器工具可用
- [ ] 超时设置合理

E2E 测试后确认：

- [ ] 所有断言通过
- [ ] 无控制台错误
- [ ] 截图/快照已保存
- [ ] 测试数据已清理
