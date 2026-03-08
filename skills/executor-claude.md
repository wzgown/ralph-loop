# Claude Code Executor

本文件定义 Ralph Loop 在 Claude Code 环境下的 Task Executor 执行指令。

## 代理信息

- **代理名称**：Claude Code (Anthropic)
- **配置文件**：`CLAUDE.md`（项目根目录）
- **Skill 安装位置**：`~/.claude/skills/ralph-loop/`

## 核心工具

| 工具 | 用途 | 示例 |
|------|------|------|
| `Read` | 读取文件 | 读取 features.json |
| `Write` | 创建新文件 | 创建 task.md |
| `Edit` | 编辑文件 | 修改 passes 字段 |
| `Bash` | 执行命令 | git commit, npm test |
| `Glob` | 文件搜索 | `**/*.ts` |
| `Grep` | 内容搜索 | 搜索 "TODO" |
| `Task` | 启动子代理 | 并行任务 |
| `Skill` | 调用技能 | `/commit` |

## 语法特点

- 工具调用通过 XML 标签格式
- 支持 MCP (Model Context Protocol) 扩展
- 权限控制通过 `allowedTools` 配置

## Task Executor 工作流

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
   - 使用 Bash: pwd
   - 使用 Bash: git log --oneline -10
   - 使用 Read: 读取 features.json

2. 选择第一个 passes: false 的功能

3. 验证基础功能
   - 使用 Bash: bash init.sh 启动开发服务器
   - 使用浏览器自动化测试基本功能
   - 发现现有 bug 先修复

4. 实现单个功能
   - 使用 Edit 或 Write 编写代码
   - 使用 Bash: npm run test
   - 端到端验证

5. 更新状态
   - 使用 Edit: 只修改 passes 字段为 true
   - 不要删除或修改其他内容

6. 提交进度
   - 使用 Bash: git add -A
   - 使用 Bash: git commit -m "feat: 完成功能 XXX"

7. 更新 progress.md
   - 使用 Edit: 添加会话记录

8. 输出完成信号
   MISSION_COMPLETE
```

## 工具调用示例

### 读取 features.json

```
使用 Read 工具读取 .ralph/current/features.json
```

### 修改 passes 字段

```
使用 Edit 工具：
- old_string: "passes": false
- new_string: "passes": true
```

### 执行测试

```
使用 Bash 工具：
- command: npm run test:e2e -- --grep 'feature-name'
```

### Git 提交

```
使用 Bash 工具：
- command: git add -A && git commit -m "feat: 完成功能 XXX"
```

## 禁止事项

- ❌ 不要一次实现多个功能
- ❌ 不要删除或修改 features.json 中的测试步骤
- ❌ 不要在未测试的情况下标记 passes: true
- ❌ 不要留下未提交的代码
- ❌ 不要修改已跳过的功能（达到最大重试次数）

## 浏览器自动化

Claude Code 支持 MCP 浏览器工具，用于端到端测试：

- `mcp__chrome-devtools__navigate_page` - 导航到页面
- `mcp__chrome-devtools__take_snapshot` - 获取页面快照
- `mcp__chrome-devtools__click` - 点击元素
- `mcp__chrome-devtools__fill` - 填写表单
- `mcp__chrome-devtools__take_screenshot` - 截图

使用这些工具验证功能的端到端行为。
