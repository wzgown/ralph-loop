#!/bin/bash
# Agent Detector - Automatically detect which AI agent environment is running
# Part of Ralph Loop Multi-Agent Support System

set -e

# Detection priority:
# 1. Explicit RALPH_AGENT environment variable
# 2. Claude Code markers
# 3. Codex CLI markers
# 4. Gemini CLI markers
# 5. OpenClaw markers
# 6. Default to claude

detect_claude_code() {
    # Claude Code sets specific environment markers
    if [[ -n "${CLAUDE_CODE_SESSION:-}" ]] || \
       [[ -n "${ANTHROPIC_API_KEY:-}" && -n "${CLAUDE_MD_FILE:-}" ]] || \
       [[ -f ".claude/CLAUDE.md" ]] || \
       [[ -n "${CLAUDE_PROJECT:-}" ]]; then
        echo "claude"
        return 0
    fi
    return 1
}

detect_codex_cli() {
    # Codex CLI markers
    if [[ -n "${CODEX_SESSION:-}" ]] || \
       [[ -n "${OPENAI_API_KEY:-}" && -f ".codexrc" ]] || \
       command -v codex &>/dev/null; then
        echo "codex"
        return 0
    fi
    return 1
}

detect_gemini_cli() {
    # Gemini CLI markers
    if [[ -n "${GEMINI_SESSION:-}" ]] || \
       [[ -n "${GOOGLE_API_KEY:-}" && -f ".geminirc" ]] || \
       command -v gemini &>/dev/null; then
        echo "gemini"
        return 0
    fi
    return 1
}

detect_openclaw() {
    # OpenClaw markers
    if [[ -n "${OPENCLAW_SESSION:-}" ]] || \
       [[ -f ".openclawrc" ]] || \
       command -v openclaw &>/dev/null; then
        echo "openclaw"
        return 0
    fi
    return 1
}

detect_agent() {
    local agent=""

    # Priority 1: Explicit environment variable
    if [[ -n "${RALPH_AGENT:-}" ]]; then
        echo "${RALPH_AGENT}"
        return 0
    fi

    # Priority 2-5: Auto-detection
    if detect_claude_code; then
        return 0
    elif detect_codex_cli; then
        return 0
    elif detect_gemini_cli; then
        return 0
    elif detect_openclaw; then
        return 0
    fi

    # Default to claude
    echo "claude"
}

# Main execution
if [[ "${1:-}" == "--detect" ]]; then
    detect_agent
elif [[ "${1:-}" == "--help" ]]; then
    echo "Usage: agent-detector.sh [--detect|--help]"
    echo ""
    echo "Options:"
    echo "  --detect    Output the detected agent type"
    echo "  --help      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  RALPH_AGENT    Force a specific agent (claude|codex|gemini|openclaw)"
    echo ""
    echo "Detection Priority:"
    echo "  1. RALPH_AGENT environment variable"
    echo "  2. Claude Code markers (CLAUDE_CODE_SESSION, .claude/CLAUDE.md)"
    echo "  3. Codex CLI markers (CODEX_SESSION, .codexrc)"
    echo "  4. Gemini CLI markers (GEMINI_SESSION, .geminirc)"
    echo "  5. OpenClaw markers (OPENCLAW_SESSION, .openclawrc)"
    echo "  6. Default: claude"
else
    detect_agent
fi
