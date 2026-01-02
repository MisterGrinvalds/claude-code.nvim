#!/bin/bash
# Claude Code Hook: PreToolUse
# Sets state to "processing" when Claude starts using a tool
# This handles: (1) initial tool use, (2) resuming after permission granted
#
# Install: Copy to ~/.claude/hooks/on-tool-start.sh and chmod +x

# Use project-specific state file (supports multiple instances)
STATE_DIR="${CLAUDE_PROJECT_DIR:-/tmp}"
echo '{"state": "processing", "timestamp": '$(date +%s)'}' > "${STATE_DIR}/.claude-state.json"
