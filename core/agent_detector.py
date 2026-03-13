#!/usr/bin/env python3
"""
Agent Detector - Automatically detect which AI agent environment is running
Part of Ralph Loop Multi-Agent Support System

Detection priority:
1. Explicit RALPH_AGENT environment variable
2. Claude Code markers
3. Codex CLI markers
4. Gemini CLI markers
5. OpenClaw markers
6. Default to claude
"""

import os
import shutil
import sys
from pathlib import Path


def detect_claude_code() -> str | None:
    """检测 Claude Code 环境"""
    if os.environ.get("CLAUDE_CODE_SESSION"):
        return "claude"
    if os.environ.get("ANTHROPIC_API_KEY") and os.environ.get("CLAUDE_MD_FILE"):
        return "claude"
    if Path(".claude/CLAUDE.md").exists():
        return "claude"
    if os.environ.get("CLAUDE_PROJECT"):
        return "claude"
    return None


def detect_codex_cli() -> str | None:
    """检测 Codex CLI 环境"""
    if os.environ.get("CODEX_SESSION"):
        return "codex"
    if os.environ.get("OPENAI_API_KEY") and Path(".codexrc").exists():
        return "codex"
    if shutil.which("codex"):
        return "codex"
    return None


def detect_gemini_cli() -> str | None:
    """检测 Gemini CLI 环境"""
    if os.environ.get("GEMINI_SESSION"):
        return "gemini"
    if os.environ.get("GOOGLE_API_KEY") and Path(".geminirc").exists():
        return "gemini"
    if shutil.which("gemini"):
        return "gemini"
    return None


def detect_openclaw() -> str | None:
    """检测 OpenClaw 环境"""
    if os.environ.get("OPENCLAW_SESSION"):
        return "openclaw"
    if Path(".openclawrc").exists():
        return "openclaw"
    if shutil.which("openclaw"):
        return "openclaw"
    return None


def detect_agent() -> str:
    """
    检测当前 AI 代理类型

    Returns:
        str: 代理类型 (claude, codex, gemini, openclaw)
    """
    # Priority 1: Explicit environment variable
    agent = os.environ.get("RALPH_AGENT")
    if agent:
        return agent

    # Priority 2-5: Auto-detection
    detectors = [
        detect_claude_code,
        detect_codex_cli,
        detect_gemini_cli,
        detect_openclaw,
    ]

    for detector in detectors:
        result = detector()
        if result:
            return result

    # Default to claude
    return "claude"


def print_help():
    """显示帮助信息"""
    print("Usage: agent_detector.py [--detect|--help]")
    print()
    print("Options:")
    print("  --detect    Output the detected agent type")
    print("  --help      Show this help message")
    print()
    print("Environment Variables:")
    print("  RALPH_AGENT    Force a specific agent (claude|codex|gemini|openclaw)")
    print()
    print("Detection Priority:")
    print("  1. RALPH_AGENT environment variable")
    print("  2. Claude Code markers (CLAUDE_CODE_SESSION, .claude/CLAUDE.md)")
    print("  3. Codex CLI markers (CODEX_SESSION, .codexrc)")
    print("  4. Gemini CLI markers (GEMINI_SESSION, .geminirc)")
    print("  5. OpenClaw markers (OPENCLAW_SESSION, .openclawrc)")
    print("  6. Default: claude")


def main():
    args = sys.argv[1:]

    if "--help" in args:
        print_help()
        sys.exit(0)

    # 默认或 --detect 都输出检测结果
    print(detect_agent())
    sys.exit(0)


if __name__ == "__main__":
    main()
