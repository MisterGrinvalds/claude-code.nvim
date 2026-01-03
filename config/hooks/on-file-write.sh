#!/bin/bash
# Claude Code Hook: PostToolUse (Write|Edit|MultiEdit)
# Signals Neovim to refresh buffers when Claude writes files

# Read hook input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
mkdir -p "$PROJECT_DIR/.claude"

# Use session-specific refresh file if session_id available
if [ -n "$SESSION_ID" ]; then
  date +%s > "$PROJECT_DIR/.claude/refresh-${SESSION_ID}"
else
  date +%s > "$PROJECT_DIR/.claude/refresh"
fi
