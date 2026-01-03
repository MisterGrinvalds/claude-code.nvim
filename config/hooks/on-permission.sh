#!/bin/bash
# Claude Code Hook: Notification (permission_prompt)
# Sets state to "waiting" when Claude needs user permission

# Read hook input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
mkdir -p "$PROJECT_DIR/.claude"

# Use session-specific state file if session_id available
if [ -n "$SESSION_ID" ]; then
  STATE_FILE="$PROJECT_DIR/.claude/state-${SESSION_ID}.json"
else
  STATE_FILE="$PROJECT_DIR/.claude/state.json"
fi

echo '{"state": "waiting", "session_id": "'"$SESSION_ID"'", "timestamp": '$(date +%s)'}' > "$STATE_FILE"
