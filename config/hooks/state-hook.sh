#!/bin/bash
# Claude Code Unified State Hook
# Single script that handles all hook events and maps them to Neovim statusline states
#
# Hook Event → Neovim State mapping:
#   SessionStart           → idle
#   UserPromptSubmit       → processing
#   PreToolUse             → processing
#   PermissionRequest      → waiting
#   Notification           → waiting (if permission_prompt)
#   PostToolUse            → processing (+ refresh signal if file write)
#   Stop                   → done
#   SubagentStop           → (no change - main agent still active)
#   SessionEnd             → (cleanup state file)

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract common fields
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Ensure .claude directory exists
mkdir -p "$PROJECT_DIR/.claude"

# Determine state file path (session-specific if available)
if [ -n "$SESSION_ID" ]; then
  STATE_FILE="$PROJECT_DIR/.claude/state-${SESSION_ID}.json"
  REFRESH_FILE="$PROJECT_DIR/.claude/refresh-${SESSION_ID}"
else
  STATE_FILE="$PROJECT_DIR/.claude/state.json"
  REFRESH_FILE="$PROJECT_DIR/.claude/refresh"
fi

# Write state to file
write_state() {
  local state="$1"
  echo "{\"state\": \"$state\", \"session_id\": \"$SESSION_ID\", \"timestamp\": $(date +%s)}" > "$STATE_FILE"
}

# Signal Neovim to refresh buffers
write_refresh() {
  date +%s > "$REFRESH_FILE"
}

# Map hook event to state
case "$HOOK_EVENT" in
  SessionStart)
    write_state "idle"
    ;;

  UserPromptSubmit)
    write_state "processing"
    ;;

  PreToolUse)
    write_state "processing"
    ;;

  PermissionRequest)
    write_state "waiting"
    ;;

  Notification)
    # Check if this is a permission prompt notification
    NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
    if [ "$NOTIFICATION_TYPE" = "permission_prompt" ]; then
      write_state "waiting"
    fi
    ;;

  PostToolUse)
    write_state "processing"
    # Check if this was a file write operation - signal buffer refresh
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
    case "$TOOL_NAME" in
      Write|Edit|MultiEdit|NotebookEdit)
        write_refresh
        ;;
    esac
    ;;

  Stop)
    write_state "done"
    ;;

  SubagentStop)
    # Subagent finished but main agent continues - no state change
    ;;

  SessionEnd)
    # Clean up state file when session ends
    rm -f "$STATE_FILE" "$REFRESH_FILE" 2>/dev/null || true
    ;;

  *)
    # Unknown event - ignore
    ;;
esac
