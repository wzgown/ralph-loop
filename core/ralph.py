#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ralph Loop v3.1 - 长时运行任务调度器 (Python 版本)

基于 Anthropic "Effective harnesses for long-running agents" 最佳实践
核心设计：
1. Initializer Agent - 首次运行设置环境
2. Feature List (JSON) - 结构化功能清单，避免过早标记完成
3. Incremental Progress - 每次只做一个功能
4. Progress File - 记录已完成的工作
5. Clean State - 每次会话结束留下干净的 git 状态
"""

import os
import sys
import json
import time
import signal
import subprocess
import argparse
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, field

# 确保 UTF-8 输出
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')
if sys.stderr.encoding != 'utf-8':
    sys.stderr.reconfigure(encoding='utf-8')

# ============================================================
# ANSI 颜色代码
# ============================================================

class Colors:
    """ANSI 颜色代码"""
    RESET = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'

    # 前景色
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'

    @staticmethod
    def colorize(text: str, color: str) -> str:
        """给文本添加颜色"""
        return f"{color}{text}{Colors.RESET}"

# ============================================================
# 配置
# ============================================================

@dataclass
class Config:
    """
    Ralph Loop v3.2 配置

    架构设计:
    - 全局 Skill 目录: ~/.claude/skills/ralph-loop/ (脚本、模板、参考文档)
    - 项目数据目录: .ralph/ (任务、队列、日志)
    """
    # 全局 Skill 目录 (脚本、模板等)
    skill_dir: Path = None
    core_dir: Path = None
    templates_dir: Path = None
    agents_dir: Path = None
    references_dir: Path = None

    # 项目数据目录 (运行时数据)
    data_dir: Path = None
    project_root: Path = None
    current_dir: Path = None
    queue_dir: Path = None
    tasks_dir: Path = None
    logs_dir: Path = None

    # 文件路径
    current_task: Path = None
    current_features: Path = None
    current_progress: Path = None
    current_init: Path = None
    current_verify: Path = None
    task_queue: Path = None
    stop_hook: Path = None
    feature_retries: Path = None

    # 参数
    max_feature_retries: int = 3
    claude_timeout: int = 1800  # 30分钟
    delay_seconds: int = 2
    agent: str = 'claude'

    def __post_init__(self):
        # 1. 确定 Skill 目录 (脚本所在位置)
        self.core_dir = Path(__file__).parent.resolve()
        self.skill_dir = self.core_dir.parent
        self.templates_dir = self.skill_dir / 'templates'
        self.agents_dir = self.skill_dir / 'agents'
        self.references_dir = self.skill_dir / 'references'

        # 2. 确定项目数据目录
        if os.environ.get('RALPH_DATA_DIR'):
            self.data_dir = Path(os.environ['RALPH_DATA_DIR']).resolve()
        else:
            # 向后兼容: 查找当前目录的 .ralph/
            cwd = Path.cwd()
            self.data_dir = cwd / '.ralph'

        self.project_root = self.data_dir.parent
        self.current_dir = self.data_dir / 'current'
        self.queue_dir = self.data_dir / 'queue'
        self.tasks_dir = self.data_dir / 'tasks'
        self.logs_dir = self.data_dir / 'logs'

        # 3. 设置文件路径
        self.current_task = self.current_dir / 'task.md'
        self.current_features = self.current_dir / 'features.json'
        self.current_progress = self.current_dir / 'progress.md'
        self.task_queue = self.queue_dir / 'task-queue.json'
        self.stop_hook = self.core_dir / 'stop-hook.sh'
        self.feature_retries = self.logs_dir / 'feature_retries.json'

        # 4. 确保数据目录存在
        for d in [self.current_dir, self.queue_dir, self.tasks_dir, self.logs_dir]:
            d.mkdir(parents=True, exist_ok=True)


# 全局配置实例
config = Config()

# 全局中断标志
interrupted = False

def detect_agent() -> str:
    """
    自动检测当前运行的 AI Agent 类型

    检测优先级:
    1. RALPH_AGENT 环境变量
    2. Claude Code 标记
    3. Codex CLI 标记
    4. Gemini CLI 标记
    5. OpenClaw 标记
    6. 默认返回 claude
    """
    # 优先级 1: 环境变量
    if os.environ.get('RALPH_AGENT'):
        return os.environ['RALPH_AGENT'].lower()

    # 优先级 2: Claude Code 标记
    if os.environ.get('CLAUDE_CODE_SESSION'):
        return 'claude'
    if Path('.claude/CLAUDE.md').exists():
        return 'claude'
    if os.environ.get('CLAUDE_PROJECT'):
        return 'claude'

    # 优先级 3: Codex CLI 标记
    if os.environ.get('CODEX_SESSION'):
        return 'codex'
    if Path('.codexrc').exists():
        return 'codex'

    # 优先级 4: Gemini CLI 标记
    if os.environ.get('GEMINI_SESSION'):
        return 'gemini'
    if Path('.geminirc').exists():
        return 'gemini'

    # 优先级 5: OpenClaw 标记
    if os.environ.get('OPENCLAW_SESSION'):
        return 'openclaw'
    if Path('.openclawrc').exists():
        return 'openclaw'

    # 默认
    return 'claude'

def signal_handler(signum, frame):
    """处理中断信号"""
    global interrupted
    interrupted = True
    ui.clear_progress()
    print()  # 换行
    ui.warn("收到中断信号，正在退出...")
    # 终止所有子进程
    try:
        # 终止可能的 claude 子进程
        subprocess.run(['pkill', '-P', str(os.getpid())], capture_output=True)
    except:
        pass
    sys.exit(130)  # 128 + SIGINT(2)

# ============================================================
# 终端 UI
# ============================================================

class RalphUI:
    """Ralph Loop 终端 UI (无外部依赖)"""

    def __init__(self):
        self._terminal_width = self._get_terminal_width()

    def _get_terminal_width(self) -> int:
        """获取终端宽度"""
        try:
            return os.get_terminal_size().columns
        except:
            return 80

    def _print_box(self, title: str, content: str, border_color: str = Colors.BLUE):
        """打印带边框的面板"""
        lines = content.split('\n')
        # 计算实际显示宽度（忽略 ANSI 代码）
        def display_width(s):
            import re
            clean = re.sub(r'\033\[[0-9;]*m', '', s)
            return len(clean)

        max_len = max(display_width(line) for line in lines + [title])
        max_len = min(max_len, self._terminal_width - 4)

        # 边框字符
        tl, tr, bl, br = '╔', '╗', '╚', '╝'
        h, v = '═', '║'

        # 打印顶部
        if title:
            title_line = f" {title} "
            top = f"{tl}{title_line}{h * (max_len - len(title_line) + 1)}{tr}"
        else:
            top = f"{tl}{h * (max_len + 2)}{tr}"
        print(Colors.colorize(top, border_color))

        # 打印内容
        for line in lines:
            clean_len = display_width(line)
            padding = ' ' * (max_len - clean_len)
            print(f"{Colors.colorize(v, border_color)} {line}{padding} {Colors.colorize(v, border_color)}")

        # 打印底部
        bottom = f"{bl}{h * (max_len + 2)}{br}"
        print(Colors.colorize(bottom, border_color))

    def header(self, title: str, subtitle: str = ""):
        """打印标题头"""
        print()
        print(Colors.colorize(f"{'═' * 60}", Colors.MAGENTA))
        print(Colors.colorize(f"  {title}", Colors.BOLD + Colors.MAGENTA))
        if subtitle:
            print(Colors.colorize(f"  {subtitle}", Colors.MAGENTA))
        print(Colors.colorize(f"{'═' * 60}", Colors.MAGENTA))
        print()

    def status_panel(self, task_name: str, iteration: int, passed: int, total: int,
                     elapsed: int, current_feature: str = "", remaining_timeout: int = 0):
        """打印状态面板"""
        # 计算进度百分比
        pct = (passed / total * 100) if total > 0 else 0
        bar_filled = int(pct / 5)  # 20 格
        bar = Colors.colorize("█" * bar_filled, Colors.GREEN) + Colors.colorize("░" * (20 - bar_filled), Colors.DIM)

        elapsed_str = self._format_time(elapsed)
        remaining_str = self._format_time(remaining_timeout) if remaining_timeout > 0 else "N/A"

        print()
        print(Colors.colorize("╔══ Ralph Loop v3.1 ══════════════════════════════════════════╗", Colors.BLUE))
        print(Colors.colorize("║", Colors.BLUE) + f" {Colors.BOLD}任务:{Colors.RESET} {task_name}" + Colors.colorize(" ║", Colors.BLUE))
        print(Colors.colorize("║", Colors.BLUE) + f" {Colors.BOLD}代理:{Colors.RESET} {config.agent.upper()}  {Colors.BOLD}循环:{Colors.RESET} #{iteration}" + Colors.colorize(" ║", Colors.BLUE))
        print(Colors.colorize("║", Colors.BLUE) + "                                                              " + Colors.colorize("║", Colors.BLUE))
        print(Colors.colorize("║", Colors.BLUE) + f" {Colors.BOLD}进度:{Colors.RESET} [{bar}] {passed}/{total} ({pct:.0f}%)" + Colors.colorize(" ║", Colors.BLUE))
        print(Colors.colorize("║", Colors.BLUE) + f" {Colors.BOLD}时间:{Colors.RESET} {elapsed_str}  {Colors.BOLD}剩余:{Colors.RESET} {remaining_str}" + Colors.colorize(" ║", Colors.BLUE))

        if current_feature:
            print(Colors.colorize("║", Colors.BLUE) + "                                                              " + Colors.colorize("║", Colors.BLUE))
            print(Colors.colorize("║", Colors.BLUE) + f" {Colors.YELLOW}{Colors.BOLD}🔄 当前:{Colors.RESET} {current_feature[:50]}" + Colors.colorize(" ║", Colors.BLUE))

        print(Colors.colorize("╚════════════════════════════════════════════════════════════════╝", Colors.BLUE))
        print()

    def features_table(self, features: List[Dict], current_id: str = None):
        """打印功能清单"""
        print()
        for f in features:
            fid = f.get('id', '?')
            desc = f.get('description', '')[:60]
            priority = f.get('priority', 'medium')
            passes = f.get('passes', False)

            # 状态图标
            if passes:
                status = Colors.colorize("✅", Colors.GREEN)
            elif fid == current_id:
                status = Colors.colorize("🔄", Colors.YELLOW)
            else:
                status = Colors.colorize("⏳", Colors.DIM)

            # 优先级标记
            if priority == 'high':
                priority_str = Colors.colorize("[high]", Colors.RED)
            elif priority == 'low':
                priority_str = Colors.colorize("[low]", Colors.DIM)
            else:
                priority_str = ""

            # 当前功能高亮
            if fid == current_id:
                print(f"  {status} {Colors.BOLD}{Colors.YELLOW}{fid}{Colors.RESET} - {desc} {priority_str}")
            else:
                print(f"  {status} {fid} - {desc} {priority_str}")

    def log(self, level: str, msg: str):
        """打印日志"""
        colors = {
            'info': Colors.BLUE,
            'ok': Colors.GREEN,
            'warn': Colors.YELLOW,
            'err': Colors.RED,
            'ralph': Colors.MAGENTA,
            'step': Colors.CYAN
        }
        icons = {
            'info': 'ℹ️',
            'ok': '✅',
            'warn': '⚠️',
            'err': '❌',
            'ralph': '🔄',
            'step': '→'
        }

        color = colors.get(level, Colors.WHITE)
        icon = icons.get(level, '•')

        print(Colors.colorize(f"{icon} {msg}", color))

    def step(self, msg: str):
        """打印步骤"""
        self.log('step', msg)

    def info(self, msg: str):
        """打印信息"""
        self.log('info', msg)

    def ok(self, msg: str):
        """打印成功"""
        self.log('ok', msg)

    def warn(self, msg: str):
        """打印警告"""
        self.log('warn', msg)

    def err(self, msg: str):
        """打印错误"""
        self.log('err', msg)

    def ralph(self, msg: str):
        """打印 Ralph 标识"""
        self.log('ralph', msg)

    def _format_time(self, seconds: int) -> str:
        """格式化时间"""
        if seconds < 60:
            return f"{seconds}s"
        elif seconds < 3600:
            m, s = divmod(seconds, 60)
            return f"{m}m {s}s"
        else:
            h, rem = divmod(seconds, 3600)
            m, s = divmod(rem, 60)
            return f"{h}h {m}m"

    def divider(self):
        """打印分隔线"""
        print(Colors.colorize("─" * 60, Colors.DIM))

    def execution_progress(self, elapsed: int, timeout: int, status: str = "运行中"):
        """显示执行进度（原地更新）"""
        remaining = timeout - elapsed
        pct = (elapsed / timeout * 100) if timeout > 0 else 0

        # 构建进度条
        bar_width = 20
        bar_filled = int(pct / 100 * bar_width)
        bar = "█" * bar_filled + "░" * (bar_width - bar_filled)

        elapsed_str = self._format_time(elapsed)
        remaining_str = self._format_time(remaining)
        timeout_str = self._format_time(timeout)

        # 使用 sys.stdout 直接输出
        line = f"\r⏳ {status} [{bar}] {elapsed_str} / {timeout_str}  剩余 {remaining_str}  "
        # 清除行尾多余字符
        line = line.ljust(80)
        sys.stdout.write(line)
        sys.stdout.flush()

    def clear_progress(self):
        """清除进度行"""
        sys.stdout.write("\r" + " " * 80 + "\r")
        sys.stdout.flush()

    def show_help(self):
        """显示帮助"""
        help_text = """
Ralph Loop v3.1 - 长时运行任务调度器

用法:
  ralph                          运行当前任务（增量模式，自动检测 agent）
  ralph --agent <type>           指定代理类型 (claude/codex/gemini/openclaw)
  ralph --detect                 显示检测到的 agent 类型
  ralph --init                   初始化新任务（Initializer Agent 模式）
  ralph --queue                  显示任务队列
  ralph --enqueue <file>         添加任务到队列
  ralph --dequeue <id>           从队列移除任务
  ralph --next                   从队列获取下一个任务
  ralph --status                 显示当前状态
  ralph --features               显示功能清单
  ralph --progress               显示进度日志
  ralph --tasks                  列出所有任务
  ralph --archive [name]         归档当前任务
  ralph --reset                  重置当前任务
  ralph --clean                  清理工作区（确保干净状态）
  ralph --help                   显示帮助

代理类型:
  --agent claude    Claude Code (Anthropic) - 默认
  --agent codex     Codex CLI (OpenAI)
  --agent gemini    Gemini CLI (Google)
  --agent openclaw  OpenClaw

自动检测:
  --detect          显示检测到的代理类型和环境信息
  (默认自动检测，无需指定 --agent)

工作模式:
  1. Initializer Agent (--init): 设置环境，创建 features.json
  2. Coding Agent (默认): 增量式工作，每次一个功能，保持干净状态

参数:
  MAX_ITERATIONS=10       最大循环次数
  MAX_FEATURE_RETRIES=3   单个功能最大重试次数
  CLAUDE_TIMEOUT=1800     单次执行超时(秒)
  RALPH_AGENT=claude      默认代理类型
"""
        self._print_box(title="帮助", content=help_text.strip(), border_color=Colors.BLUE)


# 全局 UI 实例
ui = RalphUI()

# ============================================================
# 功能重试跟踪
# ============================================================

def load_feature_retries() -> Dict[str, int]:
    """加载功能重试记录"""
    if config.feature_retries.exists():
        try:
            with open(config.feature_retries, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return {}
    return {}

def save_feature_retries(retries: Dict[str, int]):
    """保存功能重试记录"""
    with open(config.feature_retries, 'w', encoding='utf-8') as f:
        json.dump(retries, f, ensure_ascii=False, indent=2)

def increment_feature_retry(feature_id: str) -> int:
    """增加功能重试次数"""
    retries = load_feature_retries()
    retries[feature_id] = retries.get(feature_id, 0) + 1
    save_feature_retries(retries)
    return retries[feature_id]

def get_feature_retries(feature_id: str) -> int:
    """获取功能重试次数"""
    return load_feature_retries().get(feature_id, 0)

def should_skip_feature(feature_id: str) -> bool:
    """判断是否应该跳过功能"""
    return get_feature_retries(feature_id) >= config.max_feature_retries

def get_skipped_features(features: List[Dict]) -> List[str]:
    """获取被跳过的功能列表"""
    return [f['id'] for f in features if should_skip_feature(f['id'])]

# ============================================================
# JSON 工具
# ============================================================

def load_features() -> Optional[Dict]:
    """
    加载功能清单

    支持两种格式：
    1. 数组格式：[{...}, {...}]
    2. 对象格式：{"features": [{...}, {...}]}

    内部统一转换为对象格式处理
    """
    if not config.current_features.exists():
        return None
    try:
        with open(config.current_features, 'r', encoding='utf-8') as f:
            data = json.load(f)
        # 兼容两种格式：统一转换为对象格式
        if isinstance(data, list):
            return {"features": data, "_is_array_format": True}
        return data
    except Exception as e:
        ui.err(f"加载功能清单失败: {e}")
        return None

def save_features(data: Dict):
    """
    保存功能清单

    如果原始格式是数组，保存时也使用数组格式
    """
    # 如果原始是数组格式，保存时也使用数组格式
    if data.get('_is_array_format'):
        features = data.get('features', [])
        # 移除内部标记
        for f in features:
            f.pop('_is_array_format', None)
        data_to_save = features
    else:
        data_to_save = data

    with open(config.current_features, 'w', encoding='utf-8') as f:
        json.dump(data_to_save, f, ensure_ascii=False, indent=2)

def get_next_pending_feature(features: List[Dict]) -> Optional[Dict]:
    """获取下一个待处理功能"""
    for f in features:
        if not f.get('passes', False) and not should_skip_feature(f['id']):
            return f
    return None

# ============================================================
# Git 工具
# ============================================================

def git_status() -> str:
    """获取 git 状态"""
    try:
        result = subprocess.run(
            ['git', 'status', '--short'],
            cwd=config.project_root,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        return result.stdout.strip()
    except:
        return "无法获取"

def git_log(count: int = 10) -> str:
    """获取 git 日志"""
    try:
        result = subprocess.run(
            ['git', 'log', '--oneline', f'-{count}'],
            cwd=config.project_root,
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        return result.stdout.strip()
    except:
        return ""

def git_has_changes() -> bool:
    """检查是否有未提交的更改"""
    status = git_status()
    return len(status.strip()) > 0

# ============================================================
# Prompt 构建
# ============================================================

def build_coding_prompt(iteration: int, output_file: Path) -> bool:
    """
    构建上下文 Prompt，直接写入文件
    返回是否成功
    """
    # 获取执行指令文件
    executor_file = config.skill_dir / 'agents' / f'executor-{config.agent}.md'
    executor_content = ""
    if executor_file.exists():
        with open(executor_file, 'r', encoding='utf-8') as f:
            executor_content = f.read()

    # 获取 git 状态
    git_status_str = git_status()
    git_log_str = git_log(10)

    # 读取进度文件
    progress_content = ""
    if config.current_progress.exists():
        lines = open(config.current_progress, 'r', encoding='utf-8').readlines()
        progress_content = ''.join(lines[-50:])

    # 读取任务文件
    task_content = ""
    if config.current_task.exists():
        with open(config.current_task, 'r', encoding='utf-8') as f:
            task_content = f.read()

    # 获取下一个待处理功能
    features_data = load_features()
    next_feature_json = ""
    skipped_info = ""

    if features_data:
        features = features_data.get('features', [])
        next_feature = get_next_pending_feature(features)
        if next_feature:
            next_feature_json = json.dumps(next_feature, ensure_ascii=False, indent=2)

        # 获取跳过的功能
        skipped = get_skipped_features(features)
        if skipped:
            skipped_info = f"""## ⚠️ 已跳过的功能（达到最大重试次数）

以下功能已跳过，**不要尝试实现**：
{', '.join(skipped)}

---
"""

    # 构建最近提交部分
    recent_commits = ""
    if git_log_str:
        recent_commits = f"""### 最近提交
```
{git_log_str}
```
"""

    # 直接写入文件
    prompt = f"""# Ralph Loop v3.1 - Coding Agent 模式 (代理: {config.agent})

你是 Ralph Loop 的执行实例（循环 #{iteration}）。

## 🎯 核心原则（必须遵守）

1. **增量工作**: 每次只完成 **一个功能**，不要尝试一次完成多个
2. **干净状态**: 完成后确保代码可提交（无语法错误、测试通过）
3. **结构化更新**: 只修改 features.json 中的 passes 字段
4. **端到端验证**: 使用浏览器自动化工具测试功能
5. **提交进度**: 完成后 git commit 并更新 progress.md

## 📁 项目信息

- 项目目录: `{config.project_root}`
- 任务文件: `{config.current_task}`
- 功能清单: `{config.current_features}`
- 进度日志: `{config.current_progress}`
- 启动脚本: `{config.current_init}`
- 验证脚本: `{config.current_verify}`

---

## 🤖 代理执行指令 ({config.agent})

{executor_content}

---

## 📋 当前任务

{task_content}

---

## 🔧 Git 状态

```
{git_status_str}
```

{recent_commits}
---

## 📝 进度日志（最近）

{progress_content}

---

## ⏭️ 下一个待处理功能

```json
{next_feature_json}
```

{skipped_info}
---

## 📋 工作流程（必须按顺序执行）

1. **获取上下文**
   ```bash
   pwd  # 确认工作目录
   git log --oneline -10  # 查看最近提交
   ```

2. **读取功能清单**
   - 阅读 `{config.current_features}`
   - 选择第一个 `passes: false` 的功能

3. **验证基础功能**
   - 启动开发服务器（如有需要）
   - 使用浏览器自动化工具测试基本功能
   - 如果发现现有 bug，先修复

4. **实现单个功能**
   - 编写代码实现该功能
   - 运行测试验证
   - 使用浏览器自动化端到端测试

5. **更新状态**
   - 只修改 `passes` 字段为 `true`
   - **不要**删除或修改其他内容

6. **提交进度**
   ```bash
   git add -A
   git commit -m "feat: 完成功能 XXX"
   ```

7. **更新进度日志**
   - 在 `progress.md` 添加会话记录

8. **输出完成信号**
   完成后必须单独一行输出:
   ```
   MISSION_COMPLETE
   ```

## ⚠️ 禁止事项

- ❌ 不要一次实现多个功能
- ❌ 不要删除或修改 features.json 中的测试步骤
- ❌ 不要在未测试的情况下标记 passes: true
- ❌ 不要留下未提交的代码

"""

    # 写入文件
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(prompt)
        return True
    except Exception as e:
        ui.err(f"写入 prompt 文件失败: {e}")
        return False

# ============================================================
# 运行 Claude
# ============================================================

def run_claude(prompt_file: Path, log_file: Path, timeout: int) -> bool:
    """
    运行 Claude 执行任务
    返回是否成功完成（非超时）
    """
    ui.info(f"Claude 已启动 (超时: {timeout}s)")
    ui.step(f"Prompt: {prompt_file}")
    ui.step(f"日志: {log_file}")
    print()

    start_time = time.time()

    # 启动 Claude 进程
    try:
        with open(log_file, 'a', encoding='utf-8') as log_f:
            process = subprocess.Popen(
                ['claude', '--permission-mode', 'bypassPermissions', '-p', str(prompt_file)],
                stdout=log_f,
                stderr=subprocess.STDOUT,
                cwd=config.project_root
            )
    except FileNotFoundError:
        ui.clear_progress()
        ui.err("未找到 claude 命令，请确保 Claude Code 已安装")
        return False
    except Exception as e:
        ui.clear_progress()
        ui.err(f"启动 Claude 失败: {e}")
        return False

    # 等待进程完成或超时（原地更新进度）
    global interrupted
    elapsed = 0
    completed = False

    while elapsed < timeout and not interrupted:
        ret = process.poll()
        if ret is not None:
            completed = True
            break

        time.sleep(1)
        elapsed += 1

        # 原地更新进度
        ui.execution_progress(elapsed, timeout, "执行中")

    # 清除进度行
    ui.clear_progress()

    # 处理中断
    if interrupted:
        ui.warn("收到中断信号，终止 Claude 进程...")
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        return False

    # 处理超时
    if not completed:
        ui.warn("执行超时，终止进程...")
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()

    end_time = time.time()
    duration = int(end_time - start_time)

    # 获取退出码
    exit_code = process.returncode if completed else -1

    if completed and exit_code == 0:
        ui.ok(f"Claude 执行完成 (耗时: {ui._format_time(duration)})")
        return True
    else:
        ui.warn(f"Claude 执行异常 (code: {exit_code}, 耗时: {ui._format_time(duration)})")
        return False

# ============================================================
# Stop Hook 验证
# ============================================================

def run_stop_hook(log_file: Path, iteration: int) -> bool:
    """
    运行 Stop Hook 验证
    返回是否通过
    """
    ui.info("Stop Hook: 验证...")

    hook_log = log_file.with_suffix('.log.hook')

    # 设置环境变量传递 iteration
    env = os.environ.copy()
    env['RALPH_ITERATION'] = str(iteration)

    try:
        with open(hook_log, 'w', encoding='utf-8') as f:
            result = subprocess.run(
                ['bash', str(config.stop_hook)],
                cwd=config.project_root,
                stdout=f,
                stderr=subprocess.STDOUT,
                encoding='utf-8',
                env=env
            )

        if result.returncode == 0:
            ui.ok("验证通过")
            return True
        else:
            ui.warn("验证失败")
            return False
    except Exception as e:
        ui.err(f"运行 Stop Hook 失败: {e}")
        return False

# ============================================================
# 任务归档
# ============================================================

def archive_task(total_iterations: int, status: str = "completed"):
    """归档当前任务"""
    if not config.current_task.exists():
        ui.err("无当前任务可归档")
        return

    # 提取任务名称
    task_name = "task"
    with open(config.current_task, 'r', encoding='utf-8') as f:
        for line in f:
            if line.startswith('# 任务'):
                task_name = line.replace('# 任务', '').replace('#', '').strip()
                task_name = ''.join(c for c in task_name if c.isalnum() or c in '-_')
                break

    if not task_name:
        task_name = f"task-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

    archive_name = f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-{task_name}-iter{total_iterations}"
    archive_dir = config.tasks_dir / archive_name
    archive_dir.mkdir(parents=True, exist_ok=True)

    ui.info(f"归档任务到: {archive_dir}")

    # 复制文件
    files_to_copy = [
        (config.current_task, 'task.md'),
        (config.current_features, 'features.json'),
        (config.current_progress, 'progress.md'),
    ]

    for src, dst in files_to_copy:
        if src.exists():
            shutil.copy2(src, archive_dir / dst)
            ui.step(dst)

    # 复制日志
    logs_archive = archive_dir / 'logs'
    logs_archive.mkdir(exist_ok=True)

    for f in config.logs_dir.glob('*.log'):
        shutil.copy2(f, logs_archive)
    for f in config.logs_dir.glob('*.hook'):
        shutil.copy2(f, logs_archive)
    for f in config.logs_dir.glob('ralph-*.txt'):
        shutil.copy2(f, logs_archive)

    # 计算功能完成率
    feature_stats = ""
    features_data = load_features()
    if features_data:
        features = features_data.get('features', [])
        total = len(features)
        passed = sum(1 for f in features if f.get('passes', False))
        feature_stats = f"- 功能: {passed}/{total} 通过"

    # 创建摘要
    summary = f"""# 归档摘要

- 任务: {task_name}
- 完成时间: {datetime.now().isoformat()}
- 总循环次数: {total_iterations}
- 状态: ✅ {status}
{feature_stats}

## 文件清单

- task.md - 任务描述
- features.json - 功能清单
- progress.md - 进度日志
- logs/ - 循环日志
"""

    with open(archive_dir / 'SUMMARY.md', 'w', encoding='utf-8') as f:
        f.write(summary)

    # 清理当前任务文件
    for f in [config.current_task, config.current_features, config.current_progress]:
        if f.exists():
            f.unlink()

    # 清理日志
    for f in config.logs_dir.glob('*.log'):
        f.unlink()
    for f in config.logs_dir.glob('*.hook'):
        f.unlink()
    for f in config.logs_dir.glob('ralph-*.txt'):
        f.unlink()

    ui.ok(f"📁 已归档: {archive_dir}")

# ============================================================
# 任务初始化
# ============================================================

def init_task(task_file: Optional[Path] = None):
    """初始化任务"""
    task_file = task_file or config.current_task

    if not task_file.exists():
        ui.err(f"任务文件不存在: {task_file}")
        ui.info(f"创建新任务: ralph --new")
        return False

    ui.ralph("════════════════════════════════════════════════════════")
    ui.ralph("  Initializer Agent 模式")
    ui.ralph("════════════════════════════════════════════════════════")
    print()

    # 如果有现有任务，先归档
    if config.current_task.exists() and task_file != config.current_task:
        ui.info("归档现有任务...")
        archive_task(0, "initializer")

    # 复制任务文件（如果源文件不是当前任务文件）
    if task_file.resolve() != config.current_task.resolve():
        shutil.copy2(task_file, config.current_task)

    # 创建功能清单
    if not config.current_features.exists():
        template = config.templates_dir / 'features-template.json'
        shutil.copy2(template, config.current_features)

        # 更新任务信息
        task_name = ""
        with open(config.current_task, 'r', encoding='utf-8') as f:
            for line in f:
                if line.startswith('# 任务'):
                    task_name = line.replace('# 任务', '').replace('#', '').strip()
                    break

        task_id = f"F-{datetime.now().strftime('%Y%m%d%H%M%S')}"

        features_data = load_features()
        if features_data:
            features_data['task_id'] = task_id
            features_data['task_name'] = task_name
            features_data['created_at'] = datetime.now().isoformat()
            save_features(features_data)

    # 创建进度文件
    if not config.current_progress.exists():
        template = config.templates_dir / 'progress-template.md'
        shutil.copy2(template, config.current_progress)

        features_data = load_features()
        task_id = features_data.get('task_id', '') if features_data else ''
        task_name = features_data.get('task_name', '') if features_data else ''

        with open(config.current_progress, 'r', encoding='utf-8') as f:
            content = f.read()

        content = content.replace('- **任务ID**:', f'- **任务ID**: {task_id}')
        content = content.replace('- **任务名称**:', f'- **任务名称**: {task_name}')
        content = content.replace('- **开始时间**:', f'- **开始时间**: {datetime.now().isoformat()}')

        with open(config.current_progress, 'w', encoding='utf-8') as f:
            f.write(content)

    ui.ok("环境初始化完成:")
    print()
    print(f"  📄 任务描述: {config.current_task}")
    print(f"  📋 功能清单: {config.current_features}")
    print(f"  📝 进度日志: {config.current_progress}")
    print()
    ui.info("下一步:")
    print("  1. 编辑 features.json 添加功能列表")
    print("  2. 运行: ralph")

    return True

# ============================================================
# 更新进度日志
# ============================================================

def update_progress(iteration: int, success: bool, passed: int, total: int, error_msg: str = ""):
    """更新进度日志"""
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    status = "✅ 功能完成" if success else "❌ 验证失败"

    entry = f"""
---

## 会话 #{timestamp}

- 时间: {datetime.now().isoformat()}
- 循环: #{iteration}
- 状态: {status}
- 进度: {passed}/{total}
"""

    if error_msg:
        entry += f"- 错误: {error_msg[:200]}\n"

    # 读取验证错误详情（如果存在）
    verify_errors_file = Path(f"/tmp/ralph_verify_errors_{iteration}")
    if not success and verify_errors_file.exists():
        try:
            errors_content = verify_errors_file.read_text(encoding='utf-8').strip()
            if errors_content:
                entry += f"\n### 验证失败详情\n\n{errors_content}\n"
        except Exception:
            pass
        finally:
            # 清理临时文件
            try:
                verify_errors_file.unlink()
            except Exception:
                pass

    with open(config.current_progress, 'a', encoding='utf-8') as f:
        f.write(entry)

# ============================================================
# 主循环
# ============================================================

def main_loop():
    """主循环"""
    # 检查是否有任务
    if not config.current_task.exists():
        ui.err("无当前任务")
        ui.info("创建新任务: ralph --init <task-file>")
        ui.info("添加到队列: ralph --enqueue <task-file>")
        return 1

    # 检查功能清单
    if not config.current_features.exists():
        ui.warn("无功能清单，运行初始化...")
        init_task(config.current_task)

    features_data = load_features()
    if not features_data:
        ui.err("无法加载功能清单")
        return 1

    features = features_data.get('features', [])
    total_features = len(features)
    passed_features = sum(1 for f in features if f.get('passes', False))

    ui.ralph("════════════════════════════════════════════════════════")
    ui.ralph("  Ralph Loop v3.1 - Coding Agent 模式")
    ui.ralph("════════════════════════════════════════════════════════")
    ui.info(f"项目: {config.project_root}")
    ui.info(f"任务: {config.current_task}")
    ui.info(f"熔断: 单个功能最多 {config.max_feature_retries} 次重试")
    print()

    # 显示功能统计
    ui.info(f"功能进度: {passed_features}/{total_features} 通过")
    print()

    iteration = 0
    start_time = time.time()

    while True:
        # 检查中断
        global interrupted
        if interrupted:
            ui.warn("任务被中断")
            return 130

        iteration += 1
        log_file = config.logs_dir / f"iteration_{iteration:03d}.log"

        # 重新加载功能数据
        features_data = load_features()
        features = features_data.get('features', [])
        total_features = len(features)
        passed_features = sum(1 for f in features if f.get('passes', False))
        remaining = total_features - passed_features

        # 获取当前功能
        current_feature = get_next_pending_feature(features)
        current_id = current_feature['id'] if current_feature else None

        # 显示状态面板（包含循环号）
        elapsed = int(time.time() - start_time)
        ui.status_panel(
            task_name=features_data.get('task_name', '未命名'),
            iteration=iteration,
            passed=passed_features,
            total=total_features,
            elapsed=elapsed,
            current_feature=current_feature.get('description', '') if current_feature else ""
        )
        print()

        # 显示功能表格
        ui.features_table(features, current_id)
        print()

        # 检查是否完成
        if remaining == 0:
            ui.ok("════════════════════════════════════════════════════════")
            ui.ok("🎉 所有功能已完成！")
            ui.ok("════════════════════════════════════════════════════════")
            archive_task(iteration, "completed")
            return 0

        # 检查是否所有未完成功能都被跳过
        skipped = get_skipped_features(features)
        if len(skipped) >= remaining:
            ui.warn("════════════════════════════════════════════════════════")
            ui.warn("⚠️ 所有未完成功能已达到最大重试次数")
            ui.warn(f"   跳过的功能: {', '.join(skipped)}")
            ui.warn("════════════════════════════════════════════════════════")
            print()
            ui.info("可选操作:")
            print("  1. 重置重试计数: rm .ralph/logs/feature_retries.json")
            print("  2. 手动归档: ./ralph --archive")
            print("  3. 查看日志: cat .ralph/logs/iteration_*.log")
            return 1

        # 构建 prompt
        prompt_file = config.logs_dir / f"ralph-{os.getpid()}-{int(time.time())}.txt"
        ui.info("构建上下文 Prompt...")
        if not build_coding_prompt(iteration, prompt_file):
            ui.err("构建 Prompt 失败")
            return 1
        ui.step(f"Prompt 文件: {prompt_file}")

        # 运行 Claude
        claude_success = run_claude(prompt_file, log_file, config.claude_timeout)
        ui.info(f"日志已保存: {log_file}")

        # 运行 Stop Hook 验证
        hook_success = run_stop_hook(log_file, iteration)

        # 重新加载功能数据检查更新
        features_data = load_features()
        features = features_data.get('features', [])
        new_passed = sum(1 for f in features if f.get('passes', False))

        if hook_success:
            if new_passed > passed_features:
                ui.ok("════════════════════════════════════════════════════════")
                ui.ok(f"✅ 功能完成！({passed_features} → {new_passed})")
                ui.ok("════════════════════════════════════════════════════════")
                passed_features = new_passed
                update_progress(iteration, True, passed_features, total_features)
            else:
                ui.ok("验证通过，但无新功能完成")

            # 检查是否全部完成
            remaining = total_features - new_passed
            if remaining == 0:
                ui.ok("════════════════════════════════════════════════════════")
                ui.ok("🎉 所有功能已完成！任务结束")
                ui.ok("════════════════════════════════════════════════════════")
                archive_task(iteration, "completed")
                return 0
        else:
            # 失败：增加当前功能的重试计数
            if current_feature:
                retries = increment_feature_retry(current_feature['id'])
                ui.warn(f"功能 {current_feature['id']} 重试次数: {retries}/{config.max_feature_retries}")

                if retries >= config.max_feature_retries:
                    ui.err(f"功能 {current_feature['id']} 已达到最大重试次数，将被跳过")

            # 追加失败日志到任务文件
            hook_log = log_file.with_suffix('.log.hook')
            error_content = ""
            if hook_log.exists():
                with open(hook_log, 'r', encoding='utf-8') as f:
                    lines = f.readlines()[:30]
                    error_content = ''.join(lines)

            fail_entry = f"""
---

## 第 {iteration} 轮失败

```
{error_content}
```

**要求**: 修复上述错误后重新运行。

"""

            with open(config.current_task, 'a', encoding='utf-8') as f:
                f.write(fail_entry)

            update_progress(iteration, False, passed_features, total_features, error_content[:200])
            ui.info("已追加失败日志")

        # 清理旧的 prompt 文件
        for f in config.logs_dir.glob('ralph-*.txt'):
            if f.stat().st_mtime < time.time() - 86400:  # 1天前
                f.unlink()

        # 等待
        time.sleep(config.delay_seconds)

# ============================================================
# 状态显示
# ============================================================

def show_status():
    """显示当前状态"""
    ui.header("Ralph Loop v3.1 状态")

    print("📍 当前任务:")
    if config.current_task.exists():
        task_name = ""
        with open(config.current_task, 'r', encoding='utf-8') as f:
            for line in f:
                if line.startswith('# 任务'):
                    task_name = line.replace('# 任务', '').replace('#', '').strip()
                    break

        print(f"   名称: {task_name or '未命名'}")
        print(f"   文件: {config.current_task}")

        # 功能统计
        features_data = load_features()
        if features_data:
            features = features_data.get('features', [])
            total = len(features)
            passed = sum(1 for f in features if f.get('passes', False))
            print(f"   功能: {passed}/{total} 通过")

        # Git 状态
        if git_has_changes():
            print("   Git: ⚠️  有未提交的更改")
        else:
            print("   Git: ✅ 干净状态")
    else:
        print("   无当前任务")

    print()
    print("📋 任务队列:")
    if config.task_queue.exists():
        try:
            with open(config.task_queue, 'r', encoding='utf-8') as f:
                queue = json.load(f)
            pending = sum(1 for t in queue.get('tasks', []) if t.get('status') == 'pending')
            print(f"   待处理: {pending} 个任务")
        except:
            print("   队列读取失败")
    else:
        print("   队列为空")

def show_features():
    """显示功能清单"""
    ui.header("功能清单")

    features_data = load_features()
    if not features_data:
        print()
        print("无功能清单。运行 --init 创建。")
        return

    features = features_data.get('features', [])
    ui.features_table(features)

# ============================================================
# 主入口
# ============================================================

def main():
    """主入口"""
    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # 检查是否请求帮助
    if '--help' in sys.argv or '-h' in sys.argv:
        ui.show_help()
        return 0

    parser = argparse.ArgumentParser(
        description='Ralph Loop v3.1 - 长时运行任务调度器',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('--agent', '-a', choices=['claude', 'codex', 'gemini', 'openclaw'],
                        default=None,
                        help='代理类型 (claude/codex/gemini/openclaw)')
    parser.add_argument('--detect', action='store_true', help='自动检测代理类型')
    parser.add_argument('--init', '-i', metavar='FILE', help='初始化新任务')
    parser.add_argument('--queue', '-q', action='store_true', help='显示任务队列')
    parser.add_argument('--enqueue', '-e', metavar='FILE', help='添加任务到队列')
    parser.add_argument('--dequeue', '-d', metavar='ID', help='从队列移除任务')
    parser.add_argument('--next', '-n', action='store_true', help='获取下一个任务')
    parser.add_argument('--status', '-s', action='store_true', help='显示当前状态')
    parser.add_argument('--features', '-f', action='store_true', help='显示功能清单')
    parser.add_argument('--progress', '-p', action='store_true', help='显示进度日志')
    parser.add_argument('--tasks', '-l', action='store_true', help='列出所有任务')
    parser.add_argument('--archive', metavar='NAME', nargs='?', const='manual', help='归档当前任务')
    parser.add_argument('--reset', '-r', action='store_true', help='重置当前任务')
    parser.add_argument('--clean', '-c', action='store_true', help='检查工作区状态')
    parser.add_argument('--new', action='store_true', help='创建新任务')

    args = parser.parse_args()

    # 处理 --detect 命令
    if args.detect:
        detected = detect_agent()
        print(f"检测到的代理类型: {detected}")
        print()
        print("检测优先级:")
        print("  1. RALPH_AGENT 环境变量")
        print("  2. Claude Code 标记 (CLAUDE_CODE_SESSION, .claude/CLAUDE.md)")
        print("  3. Codex CLI 标记 (CODEX_SESSION, .codexrc)")
        print("  4. Gemini CLI 标记 (GEMINI_SESSION, .geminirc)")
        print("  5. OpenClaw 标记 (OPENCLAW_SESSION, .openclawrc)")
        print()
        print("环境变量:")
        print(f"  RALPH_AGENT: {os.environ.get('RALPH_AGENT', '(未设置)')}")
        print(f"  CLAUDE_CODE_SESSION: {os.environ.get('CLAUDE_CODE_SESSION', '(未设置)')}")
        print(f"  CODEX_SESSION: {os.environ.get('CODEX_SESSION', '(未设置)')}")
        print(f"  GEMINI_SESSION: {os.environ.get('GEMINI_SESSION', '(未设置)')}")
        print(f"  OPENCLAW_SESSION: {os.environ.get('OPENCLAW_SESSION', '(未设置)')}")
        return 0

    # 设置代理（自动检测或手动指定）
    if args.agent:
        config.agent = args.agent
    else:
        config.agent = detect_agent()

    # 处理命令
    if args.status:
        show_status()
        return 0

    if args.features:
        show_features()
        return 0

    if args.progress:
        if config.current_progress.exists():
            with open(config.current_progress, 'r', encoding='utf-8') as f:
                print(f.read())
        else:
            print("无进度日志")
        return 0

    if args.tasks:
        ui.header("任务列表")
        print()

        # 当前任务
        if config.current_task.exists():
            print("📍 当前任务:")
            task_name = ""
            with open(config.current_task, 'r', encoding='utf-8') as f:
                for line in f:
                    if line.startswith('# 任务'):
                        task_name = line.replace('# 任务', '').replace('#', '').strip()
                        break
            print(f"   名称: {task_name or '未命名'}")
            print()

        # 历史任务
        if config.tasks_dir.exists():
            dirs = sorted(config.tasks_dir.iterdir(), reverse=True)
            if dirs:
                print("📁 历史任务:")
                for d in dirs:
                    if d.is_dir():
                        summary_file = d / 'SUMMARY.md'
                        status = ""
                        if summary_file.exists():
                            with open(summary_file, 'r', encoding='utf-8') as f:
                                for line in f:
                                    if line.startswith('- 状态:'):
                                        status = line.replace('- 状态:', '').strip()
                                        break
                        print(f"   • {d.name} {status}")
        return 0

    if args.init:
        init_task(Path(args.init))
        return 0

    if args.new:
        if config.current_task.exists():
            ui.info("归档现有任务...")
            archive_task(0, "new-task")
        template = config.templates_dir / 'task-template.md'
        shutil.copy2(template, config.current_task)
        ui.ok(f"已创建新任务: {config.current_task}")
        ui.info("编辑任务后运行: ralph --init")
        return 0

    if args.clean:
        if git_has_changes():
            ui.warn("工作区有未提交的更改")
            print(git_status())
        else:
            ui.ok("工作区状态干净")
        return 0

    if args.archive is not None:
        archive_task(0, args.archive or "manual")
        return 0

    if args.queue:
        if config.task_queue.exists():
            with open(config.task_queue, 'r', encoding='utf-8') as f:
                print(f.read())
        else:
            print("队列为空")
        return 0

    # 默认：运行主循环
    return main_loop()


if __name__ == '__main__':
    sys.exit(main() or 0)
