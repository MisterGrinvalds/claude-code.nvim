#!/bin/bash
# Claude Code Hook: Stop
# Sets state to "done" when Claude finishes processing
#
# Install: Copy to ~/.claude/hooks/on-stop.sh and chmod +x

echo '{"state": "done", "timestamp": '$(date +%s)'}' > /tmp/claude-state.json
