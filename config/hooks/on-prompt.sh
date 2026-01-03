#!/bin/bash
# Claude Code Hook: UserPromptSubmit
# Sets state to "processing" when user sends a prompt

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

echo '{"state": "processing", "session_id": "'"$SESSION_ID"'", "timestamp": '$(date +%s)'}' > "$STATE_FILE"
