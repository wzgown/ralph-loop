# Anthropic Harnesses 参考

本文档总结 Anthropic "Effective harnesses for long-running agents" 论文中的核心概念和最佳实践，作为 Ralph Loop 设计的理论基础。

## 论文信息

- **标题**: Effective harnesses for long-running agents
- **来源**: Anthropic Research
- **相关**: Claude Agent SDK, Model Context Protocol

## 核心问题

AI 编码代理在实际应用中面临的核心挑战：

| 问题 | 表现 | 后果 |
|------|------|------|
| **一次做太多** | 尝试一次实现多个功能 | 代码质量差、难以调试 |
| **过早宣布完成** | 声称完成但实际未验证 | 功能不可用 |
| **留下混乱状态** | 未提交代码、有语法错误 | 下次会话无法继续 |
| **未正确测试** | 只运行单元测试 | 生产环境出问题 |
| **上下文丢失** | 会话结束后忘记进度 | 重复工作 |

## 解决方案框架

### 1. 增量工作 (Incremental Work)

**原则**: 每次只完成一个小任务

**实现**:
```
❌ 错误: "实现完整的用户系统"
✅ 正确: "实现登录页面 UI"
```

**Ralph Loop 实现**:
- features.json 中的每个功能独立
- 每次迭代只处理一个 `passes: false` 的功能
- 功能粒度控制在 1-2 小时

### 2. 结构化功能清单 (Feature List)

**原则**: 使用结构化格式记录待办事项

**实现**:
```json
{
  "id": "F001",
  "description": "功能描述",
  "verify_command": "验证命令",
  "passes": false
}
```

**Ralph Loop 实现**:
- features.json 作为单一事实来源
- AI 只能修改 `passes` 字段
- 客观验证而非主观判断

### 3. 干净状态 (Clean State)

**原则**: 每次会话结束确保代码可提交

**实现**:
- 无语法错误
- 测试通过
- Git 状态干净

**Ralph Loop 实现**:
- stop-hook.sh 三层验证
- MISSION_COMPLETE 信号检查
- Git 状态强制检查

### 4. 端到端验证 (End-to-End Verification)

**原则**: 使用真实浏览器验证功能

**实现**:
- 浏览器自动化工具
- 模拟真实用户操作
- 验证完整用户流程

**Ralph Loop 实现**:
- 集成 MCP 浏览器工具
- 支持 Playwright/Puppeteer
- 验证命令 + 浏览器测试

### 5. 进度记录 (Progress File)

**原则**: 记录已完成的工作

**实现**:
```markdown
## 2024-01-15
- 完成功能 F001
- 遇到问题: XXX
- 解决方案: YYY
```

**Ralph Loop 实现**:
- progress.md 自动更新
- 每次迭代记录
- 包含错误和解决方案

## Ralph Loop 架构映射

```
Anthropic Harnesses          Ralph Loop
─────────────────────────────────────────────
Incremental Work        →    features.json 功能拆分
Feature List            →    features.json 结构
Clean State             →    stop-hook.sh 验证
E2E Verification        →    浏览器自动化 + verify_command
Progress Tracking       →    progress.md
```

## 验证循环

```
         ┌────────────────────┐
         │  获取上下文         │
         │  - features.json   │
         │  - task.md         │
         └─────────┬──────────┘
                   │
                   ▼
         ┌────────────────────┐
         │  选择下一个功能     │
         │  (passes: false)   │
         └─────────┬──────────┘
                   │
                   ▼
         ┌────────────────────┐
         │  实现功能          │
         │  - 编码            │
         │  - 单元测试        │
         └─────────┬──────────┘
                   │
                   ▼
         ┌────────────────────┐
         │  E2E 验证          │
         │  - 浏览器测试      │
         │  - verify_command  │
         └─────────┬──────────┘
                   │
                   ▼
         ┌────────────────────┐
         │  更新状态          │
         │  passes: true      │
         └─────────┬──────────┘
                   │
                   ▼
         ┌────────────────────┐
         │  提交进度          │
         │  - git commit      │
         │  - progress.md     │
         └─────────┬──────────┘
                   │
                   ▼
         ┌────────────────────┐
         │  MISSION_COMPLETE  │
         └────────────────────┘
                   │
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
  ┌───────────┐        ┌───────────┐
  │ 继续下一个 │        │  任务完成  │
  │   功能    │        │           │
  └───────────┘        └───────────┘
```

## 关键设计决策

### 为什么使用 JSON 而非 Markdown？

| 特性 | JSON | Markdown |
|------|------|----------|
| 解析可靠性 | 高 | 低 |
| 程序化处理 | 容易 | 困难 |
| AI 修改安全性 | 高（只改 passes） | 低（可能改其他） |
| 验证命令支持 | 原生 | 需解析 |

### 为什么限制 AI 只修改 passes？

1. **防止范围蔓延** - AI 不会删除或修改测试步骤
2. **保持可追溯性** - 原始需求不变
3. **简化验证** - 只需检查布尔值
4. **失败恢复** - 重试时可以重新执行相同步骤

### 为什么需要 MISSION_COMPLETE 信号？

1. **明确结束** - AI 明确表示任务完成
2. **验证触发** - stop-hook.sh 检测信号后执行验证
3. **失败检测** - 未输出信号视为失败

## 扩展阅读

### 相关论文

- [Chain-of-Thought Prompting](https://arxiv.org/abs/2201.11903)
- [ReAct: Synergizing Reasoning and Acting](https://arxiv.org/abs/2210.03629)
- [Tool Use with Large Language Models](https://arxiv.org/abs/2305.16519)

### 相关工具

- [Claude Agent SDK](https://github.com/anthropics/anthropic-sdk-python)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Playwright](https://playwright.dev/)

## 总结

Ralph Loop 是 Anthropic harnesses 最佳实践的完整实现：

1. **增量执行** - 每次一个功能
2. **结构化清单** - features.json
3. **状态验证** - stop-hook.sh
4. **端到端测试** - 浏览器自动化
5. **进度追踪** - progress.md

这套框架确保 AI 代理能够可靠地完成长期运行的软件工程任务。
