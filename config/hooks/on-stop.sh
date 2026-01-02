#!/bin/bash
# Claude Code Hook: Stop
# Sets state to "done" when Claude finishes processing
#
# Install: Copy to ~/.claude/hooks/on-stop.sh and chmod +x

# Use project-specific state file (supports multiple instances)
STATE_DIR="${CLAUDE_PROJECT_DIR:-/tmp}"
echo '{"state": "done", "timestamp": '$(date +%s)'}' > "${STATE_DIR}/.claude-state.json"
