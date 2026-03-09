# Gemini CLI Executor

本文件定义 Ralph Loop 在 Gemini CLI 环境下的 Task Executor 执行指令。

## 代理信息

- **代理名称**：Gemini CLI (Google)
- **配置文件**：`GEMINI.md`（项目根目录，用于持久化记忆）
- **扩展系统**：支持第三方集成（Dynatrace, Elastic 等）

## 核心工具

| 工具 | 用途 | 说明 |
|------|------|------|
| `read_file` | 读取文件 | 获取文件内容 |
| `write_file` | 写入文件 | 创建或覆盖文件 |
| `glob` | 文件匹配 | 按模式搜索文件 |
| `search_file_content` | 内容搜索 | 类似 grep |
| `replace` | 替换内容 | 编辑文件 |
| `run_shell_command` | 执行命令 | Shell 命令 |
| `list_directory` | 列出目录 | 查看目录结构 |

## 语法特点

- `@文件名` - 引用文件内容
- `!命令` - 执行 shell 命令
- 支持交互式终端应用（vim, top）
- 扩展系统支持第三方集成

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
   - !pwd 或 run_shell_command: pwd
   - !git log --oneline -10
   - read_file: .ralph/current/features.json
   - read_file: .ralph/current/task.md（包含需求文档引用）

2. 选择第一个 passes: false 的功能

3. 阅读需求文档（重要！）
   - 检查功能是否有 requirement_refs 字段
   - 如有，读取相关需求文档（如 requirements/auth.md）
   - 理解完整的业务规则后再开始实现

4. 验证基础功能
   - !bash .ralph/current/init.sh 启动开发服务器
   - 使用浏览器自动化测试基本功能
   - 发现现有 bug 先修复

5. 实现单个功能
   - 使用 replace 编辑代码
   - !npm run test
   - 端到端验证

6. 更新状态
   - 使用 replace: 只修改 passes 字段为 true
   - 不要删除或修改其他内容

7. 提交进度
   - !git add -A
   - !git commit -m "feat: 完成功能 XXX"

8. 更新 progress.md
   - 使用 replace: 添加会话记录

9. 输出完成信号
   MISSION_COMPLETE
```

## 工具调用示例

### 读取文件

```
read_file .ralph/current/features.json
```

或使用 @ 语法：

```
@.ralph/current/features.json
```

### 编辑文件

```
replace src/component.ts
old: export function oldName()
new: export function newName()
```

### 执行命令

两种方式：

```
!npm run test
```

或

```
run_shell_command: npm run test
```

### Git 操作

```
!git add -A && git commit -m "feat: 完成功能 XXX"
```

## 禁止事项

- ❌ 不要一次实现多个功能
- ❌ 不要删除或修改 features.json 中的测试步骤
- ❌ 不要在未测试的情况下标记 passes: true
- ❌ 不要留下未提交的代码
- ❌ 不要修改已跳过的功能（达到最大重试次数）

## 配置文件示例

在项目根目录创建 `GEMINI.md`：

```markdown
# Project Memory

## Ralph Loop 任务调度

使用 .ralph/skill.md 作为 Ralph Loop 任务调度指南。

### 工作流程

1. read_file .ralph/current/features.json
2. 选择未完成的功能
3. 使用 replace 实现代码
4. !npm run test
5. replace features.json 更新 passes
6. !git commit
7. MISSION_COMPLETE
```

## 扩展工具

Gemini CLI 支持以下扩展工具：

- `ask_user` - 向用户提问
- `save_memory` - 保存到 GEMINI.md
- `write_todos` - 写入待办事项
- `activate_skill` - 激活技能
- `browser_agent` - 浏览器自动化
- `web_fetch` - 获取网页
- `google_web_search` - Google 搜索

使用 `browser_agent` 进行端到端测试验证。
