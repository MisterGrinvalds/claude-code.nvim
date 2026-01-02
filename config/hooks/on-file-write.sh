#!/bin/bash
# Claude Code Hook: PostToolUse (Write|Edit|MultiEdit)
# Signals Neovim to refresh buffers when Claude writes files
#
# Install: Copy to ~/.claude/hooks/on-file-write.sh and chmod +x

date +%s > /tmp/claude-refresh
