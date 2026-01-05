#!/bin/bash
# Clear tmux window alert when window is selected
#
# Add to tmux.conf (installed automatically by install.sh):
#   # Keyboard navigation
#   set-hook -g after-select-window 'if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option window-status-format \"#{@original_format}\" ; set-window-option window-status-current-format \"#{@original_current_format}\""'
#   # Mouse clicks
#   set-hook -g session-window-changed 'if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option window-status-format \"#{@original_format}\" ; set-window-option window-status-current-format \"#{@original_current_format}\""'
#
# Or use this script for both:
#   set-hook -g after-select-window 'run-shell -b ~/.claude/hooks/clear-alert.sh'
#   set-hook -g session-window-changed 'run-shell -b ~/.claude/hooks/clear-alert.sh'

# Check if this window has an alert set (using current window context)
ALERT=$(tmux show-window-options -v @alert 2>/dev/null)

if [ "$ALERT" = "1" ]; then
  # Clear alert and restore original formats (preserves user's custom theme)
  ORIG_FMT=$(tmux show-window-options -v @original_format 2>/dev/null)
  ORIG_CURR_FMT=$(tmux show-window-options -v @original_current_format 2>/dev/null)

  tmux set-window-option @alert 0
  [ -n "$ORIG_FMT" ] && tmux set-window-option window-status-format "$ORIG_FMT"
  [ -n "$ORIG_CURR_FMT" ] && tmux set-window-option window-status-current-format "$ORIG_CURR_FMT"
fi
