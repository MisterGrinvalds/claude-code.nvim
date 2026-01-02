#!/bin/bash
# Claude Code Hook: UserPromptSubmit
# Sets state to "processing" when user sends a prompt
#
# Install: Copy to ~/.claude/hooks/on-prompt.sh and chmod +x

# Use project-specific state file (supports multiple instances)
STATE_DIR="${CLAUDE_PROJECT_DIR:-/tmp}"
echo '{"state": "processing", "timestamp": '$(date +%s)'}' > "${STATE_DIR}/.claude-state.json"
