#!/bin/bash
# Claude Code Hook: UserPromptSubmit
# Sets state to "processing" when user sends a prompt
#
# Install: Copy to ~/.claude/hooks/on-prompt.sh and chmod +x

echo '{"state": "processing", "timestamp": '$(date +%s)'}' > /tmp/claude-state.json
