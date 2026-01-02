#!/bin/bash
# Claude Code Hook: PostToolUse (Write|Edit|MultiEdit)
# Signals Neovim to refresh buffers when Claude writes files
#
# Install: Copy to ~/.claude/hooks/on-file-write.sh and chmod +x

# Use project-specific refresh file (supports multiple instances)
STATE_DIR="${CLAUDE_PROJECT_DIR:-/tmp}"
date +%s > "${STATE_DIR}/.claude-refresh"
