#!/bin/bash
# Claude Code Hook: Notification (permission_prompt)
# Sets state to "waiting" when Claude needs user permission
#
# Install: Copy to ~/.claude/hooks/on-permission.sh and chmod +x

# Use project-specific state file (supports multiple instances)
STATE_DIR="${CLAUDE_PROJECT_DIR:-/tmp}"
echo '{"state": "waiting", "timestamp": '$(date +%s)'}' > "${STATE_DIR}/.claude-state.json"
