# Tmux Window Alert System

This document describes the tmux window alert system available in the dotfiles. These functions can be used to notify users when long-running Claude operations complete.

## Overview

The alert system highlights tmux window tabs with color when triggered, and automatically clears the highlight when you switch to that window. This is useful for:

- Notifying when Claude finishes a long task
- Alerting on errors or important events
- Drawing attention to windows that need review

## Requirements

- tmux 2.0+ with the dotfiles configuration
- The `clear-alert.sh` script deployed to `~/.config/tmux/scripts/`
- Shell functions loaded from dotfiles

## Shell Functions

### `tmux_alert`

Sets a red (high priority) alert on the current window.

```bash
tmux_alert
# Output: Alert set for window @1
```

### `tmux_alert_color <color>`

Sets an alert with a custom color (hex or color name).

```bash
tmux_alert_color "#89b4fa"  # blue
tmux_alert_color yellow
```

### Priority Levels

Three convenience functions using Catppuccin Mocha colors:

| Function | Color | Hex | Use Case |
|----------|-------|-----|----------|
| `tmux_alert_high` | Red | #f38ba8 | Errors, failures |
| `tmux_alert_medium` | Yellow | #f9e2af | Warnings, needs attention |
| `tmux_alert_low` | Teal | #94e2d5 | Success, task complete |

## Usage Examples

### After Long Commands

```bash
# Alert when command finishes
./long-running-script.sh && tmux_alert

# Different alerts for success/failure
make build && tmux_alert_low || tmux_alert_high

# Alert when SSH session ends
ssh remote-server; tmux_alert
```

### In Scripts

```bash
#!/bin/bash
# notify-on-complete.sh

do_work() {
    # ... long running work ...
}

if do_work; then
    tmux_alert_low
else
    tmux_alert_high
fi
```

### From Claude/Neovim

When Claude completes a task, trigger an alert:

```bash
# In a hook or callback
tmux_alert_low  # Task completed successfully
```

## How It Works

### 1. Triggering an Alert

When `tmux_alert` is called:

```bash
tmux_alert() {
    # Get current window ID
    local window_id=$(tmux display-message -p '#{window_id}')

    # Set custom flag to mark window as alerted
    tmux set-window-option -t "$window_id" @alert 1

    # Change window status style to highlight color
    tmux set-window-option -t "$window_id" window-status-style "fg=#f38ba8,bold,bg=#45475a"
}
```

### 2. Auto-Clear on Focus

The `tmux.conf` includes a hook that fires when switching windows:

```bash
set-hook -g after-select-window 'run-shell "~/.config/tmux/scripts/clear-alert.sh #{window_id}"'
```

### 3. Clear Script

The `clear-alert.sh` script checks and clears the alert:

```bash
#!/bin/bash
WINDOW_ID="$1"

ALERT_FLAG=$(tmux show-window-options -t "$WINDOW_ID" -v @alert 2>/dev/null)

if [ "$ALERT_FLAG" = "1" ]; then
    tmux set-window-option -t "$WINDOW_ID" @alert 0
    tmux set-window-option -t "$WINDOW_ID" window-status-style "fg=#bac2de,bg=#45475a"
fi
```

## tmux.conf Configuration

Required additions to `tmux.conf`:

```bash
# Fast status updates for alert visibility
set -g status-interval 1

# Hook to clear alerts when switching windows
set-hook -g after-select-window 'run-shell "~/.config/tmux/scripts/clear-alert.sh #{window_id}"'
```

## Integration with claude-code.nvim

To use these alerts from the Neovim plugin:

### Option 1: Shell Command

```lua
-- After Claude task completes
vim.fn.system('tmux_alert_low')
```

### Option 2: Direct tmux Command

```lua
-- Skip shell function, call tmux directly
local function tmux_alert(color)
    color = color or "#f38ba8"
    local window_id = vim.fn.system("tmux display-message -p '#{window_id}'"):gsub("%s+", "")
    vim.fn.system(string.format("tmux set-window-option -t %s @alert 1", window_id))
    vim.fn.system(string.format("tmux set-window-option -t %s window-status-style 'fg=%s,bold,bg=#45475a'", window_id, color))
end

-- Usage
tmux_alert()           -- red (error)
tmux_alert("#94e2d5")  -- teal (success)
```

### Option 3: Lua Module

Create a dedicated module for tmux integration:

```lua
-- lua/claude-code/tmux.lua
local M = {}

M.colors = {
    high = "#f38ba8",    -- red
    medium = "#f9e2af",  -- yellow
    low = "#94e2d5",     -- teal
}

function M.alert(level)
    if not os.getenv("TMUX") then return end

    local color = M.colors[level] or M.colors.high
    vim.fn.system(string.format("tmux_alert_color '%s'", color))
end

function M.alert_high() M.alert("high") end
function M.alert_medium() M.alert("medium") end
function M.alert_low() M.alert("low") end

return M
```

Usage:

```lua
local tmux = require("claude-code.tmux")

-- On task complete
tmux.alert_low()

-- On error
tmux.alert_high()
```

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| tmux.conf | `~/.config/tmux/tmux.conf` | Main config with hook |
| clear-alert.sh | `~/.config/tmux/scripts/clear-alert.sh` | Auto-clear script |
| functions.sh | dotfiles `components/tmux/functions.sh` | Shell functions |

## Catppuccin Mocha Color Reference

| Color | Hex | CSS Variable |
|-------|-----|--------------|
| Red | #f38ba8 | --ctp-red |
| Yellow | #f9e2af | --ctp-yellow |
| Teal | #94e2d5 | --ctp-teal |
| Peach | #fab387 | --ctp-peach |
| Blue | #89b4fa | --ctp-blue |
| Surface1 | #45475a | --ctp-surface1 |
| Text | #bac2de | --ctp-subtext1 |
