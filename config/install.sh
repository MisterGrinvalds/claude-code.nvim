#!/bin/bash
# Claude Code Neovim Integration - Configuration Installer
# Installs hooks and statusline bridge for claude-code.nvim
#
# Usage: ./install.sh [--force] [--merge]
#   --force  Overwrite existing hook files
#   --merge  Auto-merge settings.json using jq (creates backup)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse flags
FORCE=false
MERGE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --merge) MERGE=true ;;
  esac
done

# Create directories
info "Creating directories..."
mkdir -p "$HOOKS_DIR"

# Install unified state hook
info "Installing state hook..."
HOOK_SRC="$SCRIPT_DIR/hooks/state-hook.sh"
HOOK_DEST="$HOOKS_DIR/state-hook.sh"

if [[ -L "$HOOK_DEST" ]] && [[ "$(readlink "$HOOK_DEST")" == "$HOOK_SRC" ]]; then
  info "  Already symlinked: state-hook.sh (development mode)"
elif [[ -f "$HOOK_DEST" ]] && [[ "$FORCE" != true ]]; then
  warn "Hook already exists: state-hook.sh (use --force to overwrite)"
else
  rm -f "$HOOK_DEST"
  cp "$HOOK_SRC" "$HOOK_DEST"
  chmod +x "$HOOK_DEST"
  info "  Installed: state-hook.sh"
fi

# Install statusline bridge
info "Installing statusline bridge..."
BRIDGE_SRC="$SCRIPT_DIR/statusline-bridge.sh"
BRIDGE_DEST="$CLAUDE_DIR/statusline-bridge.sh"
if [[ -L "$BRIDGE_DEST" ]] && [[ "$(readlink "$BRIDGE_DEST")" == "$BRIDGE_SRC" ]]; then
  info "  Already symlinked: statusline-bridge.sh (development mode)"
elif [[ -f "$BRIDGE_DEST" ]] && [[ "$FORCE" != true ]]; then
  warn "Statusline bridge already exists (use --force to overwrite)"
else
  rm -f "$BRIDGE_DEST"
  cp "$BRIDGE_SRC" "$BRIDGE_DEST"
  chmod +x "$BRIDGE_DEST"
  info "  Installed: statusline-bridge.sh"
fi

# Check for jq (required by hooks)
if ! command -v jq &> /dev/null; then
  warn "jq is not installed. Hooks require jq for JSON parsing."
  warn "Install with: brew install jq (macOS) or apt install jq (Linux)"
fi

# Install tmux clear-alert hook
info "Installing tmux clear-alert hook..."
CLEAR_ALERT_SRC="$SCRIPT_DIR/hooks/clear-alert.sh"
CLEAR_ALERT_DEST="$HOOKS_DIR/clear-alert.sh"

if [[ -L "$CLEAR_ALERT_DEST" ]] && [[ "$(readlink "$CLEAR_ALERT_DEST")" == "$CLEAR_ALERT_SRC" ]]; then
  info "  Already symlinked: clear-alert.sh (development mode)"
elif [[ -f "$CLEAR_ALERT_DEST" ]] && [[ "$FORCE" != true ]]; then
  warn "Hook already exists: clear-alert.sh (use --force to overwrite)"
else
  rm -f "$CLEAR_ALERT_DEST"
  cp "$CLEAR_ALERT_SRC" "$CLEAR_ALERT_DEST"
  chmod +x "$CLEAR_ALERT_DEST"
  info "  Installed: clear-alert.sh"
fi

# Clean up old hooks if they exist
OLD_HOOKS=("on-prompt.sh" "on-tool-start.sh" "on-permission.sh" "on-stop.sh" "on-file-write.sh")
for old_hook in "${OLD_HOOKS[@]}"; do
  if [[ -f "$HOOKS_DIR/$old_hook" ]]; then
    info "Removing legacy hook: $old_hook"
    rm -f "$HOOKS_DIR/$old_hook"
  fi
done

# Settings.json handling
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
info ""
info "Settings configuration..."

if [[ -f "$SETTINGS_FILE" ]]; then
  if [[ "$MERGE" == true ]]; then
    # Auto-merge using jq
    if ! command -v jq &> /dev/null; then
      error "jq is required for --merge but not installed"
      error "Install with: brew install jq (macOS) or apt install jq (Linux)"
      exit 1
    fi
    info "Merging settings.json..."
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
    jq -s '.[0] * .[1]' "$SETTINGS_FILE.bak" "$SCRIPT_DIR/settings.json" > "$SETTINGS_FILE"
    info "  Merged: settings.json (backup: settings.json.bak)"
  else
    warn "Existing settings.json found at $SETTINGS_FILE"
    info ""
    info "Run with --merge to automatically merge, or manually add:"
    info ""
    cat << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-bridge.sh",
    "padding": 0
  },
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/state-hook.sh" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/state-hook.sh" }] }],
    "PreToolUse": [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/hooks/state-hook.sh" }] }],
    "PermissionRequest": [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/hooks/state-hook.sh" }] }],
    "PostToolUse": [{ "matcher": "", "hooks": [{ "type": "command", "command": "~/.claude/hooks/state-hook.sh" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/state-hook.sh" }] }],
    "SubagentStop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/state-hook.sh" }] }],
    "SessionEnd": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/state-hook.sh" }] }]
  }
}
EOF
    info ""
    info "Reference config available at: $SCRIPT_DIR/settings.json"
  fi
else
  info "No existing settings.json found. Installing default..."
  cp "$SCRIPT_DIR/settings.json" "$SETTINGS_FILE"
  info "  Installed: settings.json"
fi

# Tmux hook configuration
TMUX_CONF="$HOME/.tmux.conf"
TMUX_HOOK_MARKER="# claude-code.nvim alert hook"

info ""
info "Tmux configuration..."

TMUX_CLEAR_CMD='if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option window-status-format \"#{@original_format}\" ; set-window-option window-status-current-format \"#{@original_current_format}\""'

if [[ -n "$TMUX" ]]; then
  # We're inside tmux - can configure directly
  if tmux show-hooks -g 2>/dev/null | grep -q "after-select-window.*@alert"; then
    info "  Tmux hooks already configured (runtime)"
  else
    info "  Adding tmux alert-clear hooks..."
    tmux set-hook -g after-select-window "$TMUX_CLEAR_CMD"
    tmux set-hook -g session-window-changed "$TMUX_CLEAR_CMD"
    info "  Installed: after-select-window, session-window-changed hooks"
  fi
fi

# Also add to tmux.conf for persistence
if [[ -f "$TMUX_CONF" ]]; then
  if grep -q "$TMUX_HOOK_MARKER" "$TMUX_CONF"; then
    info "  Tmux hook already in ~/.tmux.conf"
  else
    info "  Adding hook to ~/.tmux.conf..."
    cat >> "$TMUX_CONF" << 'EOF'

# claude-code.nvim alert hooks - clears window alert on focus (keyboard + mouse)
# Restores original format from @original_format/@original_current_format saved by the plugin
set-hook -g after-select-window 'if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option window-status-format \"#{@original_format}\" ; set-window-option window-status-current-format \"#{@original_current_format}\""'
set-hook -g session-window-changed 'if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option window-status-format \"#{@original_format}\" ; set-window-option window-status-current-format \"#{@original_current_format}\""'
EOF
    info "  Installed: ~/.tmux.conf hooks"
    if [[ -z "$TMUX" ]]; then
      warn "  Run 'tmux source-file ~/.tmux.conf' to apply"
    fi
  fi
else
  info "  Creating ~/.tmux.conf with alert hooks..."
  cat > "$TMUX_CONF" << 'EOF'
# claude-code.nvim alert hooks - clears window alert on focus (keyboard + mouse)
# Restores original format from @original_format/@original_current_format saved by the plugin
set-hook -g after-select-window 'if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option window-status-format \"#{@original_format}\" ; set-window-option window-status-current-format \"#{@original_current_format}\""'
set-hook -g session-window-changed 'if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option window-status-format \"#{@original_format}\" ; set-window-option window-status-current-format \"#{@original_current_format}\""'
EOF
  info "  Created: ~/.tmux.conf"
fi

info ""
info "Installation complete!"
info ""
info "Hook event → Neovim state mapping:"
info "  SessionStart      → idle"
info "  UserPromptSubmit  → processing"
info "  PreToolUse        → processing"
info "  PermissionRequest → waiting"
info "  PostToolUse       → processing (+ buffer refresh on file writes)"
info "  Stop              → done"
info "  SessionEnd        → (cleanup)"
info ""
info "Tmux alerts: Window tab changes color when Claude needs attention or completes."
info "             Color clears automatically when you switch to the window."
info ""
info "Next steps:"
info "  1. Restart Claude Code for hooks to take effect"
info "  2. Ensure claude-code.nvim is installed in Neovim"
