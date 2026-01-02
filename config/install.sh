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

# Install hooks
info "Installing hooks..."
for hook in "$SCRIPT_DIR/hooks/"*.sh; do
  name=$(basename "$hook")
  dest="$HOOKS_DIR/$name"

  if [[ -f "$dest" ]] && [[ "$FORCE" != true ]]; then
    warn "Hook already exists: $name (use --force to overwrite)"
  else
    cp "$hook" "$dest"
    chmod +x "$dest"
    info "  Installed: $name"
  fi
done

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

# Check for jq (required by statusline-bridge.sh)
if ! command -v jq &> /dev/null; then
  warn "jq is not installed. Statusline bridge requires jq."
  warn "Install with: brew install jq (macOS) or apt install jq (Linux)"
fi

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
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/on-tool-start.sh" }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/on-prompt.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/on-file-write.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/on-stop.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/on-permission.sh" }
        ]
      }
    ]
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
info "Next steps:"
info "  1. Restart Claude Code for hooks to take effect"
info "  2. Ensure claude-code.nvim is installed in Neovim"
info "  3. Run :checkhealth claude-code (if available)"
