#!/bin/bash
# Clear tmux window alert when window is selected
#
# Add to tmux.conf (installed automatically by install.sh):
#   # Keyboard navigation
#   set-hook -g after-select-window 'if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option -u window-status-format ; set-window-option -u window-status-current-format"'
#   # Mouse clicks
#   set-hook -g session-window-changed 'if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option -u window-status-format ; set-window-option -u window-status-current-format"'
#
# Or use this script for both:
#   set-hook -g after-select-window 'run-shell -b ~/.claude/hooks/clear-alert.sh'
#   set-hook -g session-window-changed 'run-shell -b ~/.claude/hooks/clear-alert.sh'

# Check if this window has an alert set (using current window context)
ALERT=$(tmux show-window-options -v @alert 2>/dev/null)

if [ "$ALERT" = "1" ]; then
  # Clear alert and unset window-specific formats to fall back to global
  tmux set-window-option @alert 0
  tmux set-window-option -u window-status-format
  tmux set-window-option -u window-status-current-format
  tmux set-window-option -u @original_format 2>/dev/null
  tmux set-window-option -u @original_current_format 2>/dev/null
fi
