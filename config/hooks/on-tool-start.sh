#!/bin/bash
# Claude Code Hook: PreToolUse
# Sets state to "processing" when Claude starts using a tool
# This handles: (1) initial tool use, (2) resuming after permission granted
#
# Install: Copy to ~/.claude/hooks/on-tool-start.sh and chmod +x

echo '{"state": "processing", "timestamp": '$(date +%s)'}' > /tmp/claude-state.json
