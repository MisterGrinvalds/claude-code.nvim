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
#
# Tmux alerts are triggered directly from this hook for standalone Claude usage.
# When running in Neovim, the plugin also handles alerts via lua/claude-code/tmux.lua.

set -euo pipefail

# Catppuccin Mocha colors
COLOR_PROCESSING="#f9e2af"  # yellow
COLOR_WAITING="#fab387"     # orange/peach
COLOR_DONE="#a6e3a1"        # green
COLOR_BG="#45475a"          # surface1

# Get window ID for THIS process's pane (not the focused window)
get_window_id() {
  # TMUX_PANE is set by tmux for each pane - use it to find OUR window
  if [ -n "${TMUX_PANE:-}" ]; then
    tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null
  else
    tmux display-message -p '#{window_id}' 2>/dev/null
  fi
}

# Strip #[...] style codes from format string
strip_styles() {
  echo "$1" | sed 's/#\[[^]]*\]//g'
}

# Check if format contains our alert colors (meaning it's our format, not original)
is_our_format() {
  echo "$1" | grep -qE "#a6e3a1|#f9e2af|#fab387|#f38ba8"
}

# Tmux alert function - sets window tab color
tmux_alert() {
  [ -z "${TMUX:-}" ] && return 0
  local color="${1:-$COLOR_DONE}"
  local window_id
  window_id=$(get_window_id) || return 0
  [ -z "$window_id" ] && return 0

  # Get saved original format, or save it now
  local orig
  orig=$(tmux show-window-options -t "$window_id" -v @original_format 2>/dev/null) || true

  # If no saved format, or saved format is actually our alert format, get fresh from global
  if [ -z "$orig" ] || is_our_format "$orig"; then
    # Always get from global to ensure we have the real original
    orig=$(tmux show-options -gv window-status-format 2>/dev/null) || true
    [ -z "$orig" ] && orig='#I:#W#F'
    tmux set-window-option -t "$window_id" @original_format "$orig" 2>/dev/null || true

    # Also save current window format from global
    local curr
    curr=$(tmux show-options -gv window-status-current-format 2>/dev/null) || true
    [ -z "$curr" ] && curr='#I:#W#F'
    tmux set-window-option -t "$window_id" @original_current_format "$curr" 2>/dev/null || true
  fi

  # Strip existing style codes and apply our colors
  local plain_format plain_current
  plain_format=$(strip_styles "$orig")
  plain_current=$(strip_styles "$(tmux show-window-options -t "$window_id" -v @original_current_format 2>/dev/null)")
  [ -z "$plain_current" ] && plain_current="$plain_format"

  # Set alert flag and colored formats
  tmux set-window-option -t "$window_id" @alert 1 2>/dev/null || true
  tmux set-window-option -t "$window_id" window-status-format "#[fg=$color,bold,bg=$COLOR_BG]${plain_format}#[default]" 2>/dev/null || true
  tmux set-window-option -t "$window_id" window-status-current-format "#[fg=$color,bold,bg=$COLOR_BG]${plain_current}#[default]" 2>/dev/null || true
}

# Tmux clear function - restores original window format by unsetting overrides
tmux_clear() {
  [ -z "${TMUX:-}" ] && return 0
  local window_id
  window_id=$(get_window_id) || return 0
  [ -z "$window_id" ] && return 0

  # Clear alert flag
  tmux set-window-option -t "$window_id" @alert 0 2>/dev/null || true

  # Unset window-specific format overrides (lets global theme take over)
  tmux set-window-option -t "$window_id" -u window-status-format 2>/dev/null || true
  tmux set-window-option -t "$window_id" -u window-status-current-format 2>/dev/null || true

  # Unset saved format metadata
  tmux set-window-option -t "$window_id" -u @original_format 2>/dev/null || true
  tmux set-window-option -t "$window_id" -u @original_current_format 2>/dev/null || true
}

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
    tmux_clear
    ;;

  UserPromptSubmit)
    write_state "processing"
    tmux_alert "$COLOR_PROCESSING"
    ;;

  PreToolUse)
    write_state "processing"
    tmux_alert "$COLOR_PROCESSING"
    ;;

  PermissionRequest)
    write_state "waiting"
    tmux_alert "$COLOR_WAITING"
    ;;

  Notification)
    # Check if this is a permission prompt notification
    NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
    if [ "$NOTIFICATION_TYPE" = "permission_prompt" ]; then
      write_state "waiting"
      tmux_alert "$COLOR_WAITING"
    fi
    ;;

  PostToolUse)
    write_state "processing"
    tmux_alert "$COLOR_PROCESSING"
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
    tmux_alert "$COLOR_DONE"
    ;;

  SubagentStop)
    # Subagent finished but main agent continues - no state change
    ;;

  SessionEnd)
    # Clear tmux alert and clean up state files
    tmux_clear
    write_state "idle"
    sleep 0.1  # Brief delay to ensure Neovim picks up the state change
    rm -f "$STATE_FILE" "$REFRESH_FILE" 2>/dev/null || true
    ;;

  *)
    # Unknown event - ignore
    ;;
esac
