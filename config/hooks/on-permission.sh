#!/bin/bash
# Claude Code Hook: Notification (permission_prompt)
# Sets state to "waiting" when Claude needs user permission
#
# Install: Copy to ~/.claude/hooks/on-permission.sh and chmod +x

echo '{"state": "waiting", "timestamp": '$(date +%s)'}' > /tmp/claude-state.json
