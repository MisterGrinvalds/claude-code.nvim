#!/bin/bash
# Claude Code Neovim Integration - Configuration Installer
# Installs hooks and statusline bridge for claude-code.nvim
#
# Usage: ./install.sh [--force]

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

# Check for --force flag
FORCE=false
if [[ "$1" == "--force" ]]; then
  FORCE=true
fi

# Create directories
info "Creating directories..."
mkdir -p "$HOOKS_DIR"

# Install unified state hook
info "Installing state hook..."
HOOK_SRC="$SCRIPT_DIR/hooks/state-hook.sh"
HOOK_DEST="$HOOKS_DIR/state-hook.sh"

if [[ -f "$HOOK_DEST" ]] && [[ "$FORCE" != true ]]; then
  warn "Hook already exists: state-hook.sh (use --force to overwrite)"
else
  cp "$HOOK_SRC" "$HOOK_DEST"
  chmod +x "$HOOK_DEST"
  info "  Installed: state-hook.sh"
fi

# Install statusline bridge
info "Installing statusline bridge..."
BRIDGE_DEST="$CLAUDE_DIR/statusline-bridge.sh"
if [[ -f "$BRIDGE_DEST" ]] && [[ "$FORCE" != true ]]; then
  warn "Statusline bridge already exists (use --force to overwrite)"
else
  cp "$SCRIPT_DIR/statusline-bridge.sh" "$BRIDGE_DEST"
  chmod +x "$BRIDGE_DEST"
  info "  Installed: statusline-bridge.sh"
fi

# Check for jq (required by hooks)
if ! command -v jq &> /dev/null; then
  warn "jq is not installed. Hooks require jq for JSON parsing."
  warn "Install with: brew install jq (macOS) or apt install jq (Linux)"
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
  warn "Existing settings.json found at $SETTINGS_FILE"
  info ""
  info "You need to manually merge the hooks configuration."
  info "Add the following to your settings.json:"
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
else
  info "No existing settings.json found. Installing default..."
  cp "$SCRIPT_DIR/settings.json" "$SETTINGS_FILE"
  info "  Installed: settings.json"
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
info "Next steps:"
info "  1. Restart Claude Code for hooks to take effect"
info "  2. Ensure claude-code.nvim is installed in Neovim"
