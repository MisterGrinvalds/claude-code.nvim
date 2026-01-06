# Tmux Window Alert System

The tmux alert system highlights window tabs with color based on Claude's state, helping you know when Claude needs attention or has completed work.

## How It Works

### State → Color Mapping

| State | Color | Meaning |
|-------|-------|---------|
| Processing | Yellow (#f9e2af) | Claude is working |
| Waiting | Orange (#fab387) | Claude needs input/permission |
| Done | Green (#a6e3a1) | Task completed |
| Idle | (normal) | No activity |

### Alert Flow

1. **Claude state changes** → Shell hook (`state-hook.sh`) or Lua module triggers tmux alert
2. **Window tab changes color** → Visual indicator in tmux status bar
3. **User switches to window** → Alert auto-clears via tmux hooks or FocusGained

## Architecture

### For Standalone Claude (terminal)

The `~/.claude/hooks/state-hook.sh` script handles both:
- Writing state to `.claude/state-*.json` (for Neovim statusline)
- Triggering tmux alerts directly

```
Claude CLI → state-hook.sh → tmux set-window-option (color change)
```

### For Neovim-hosted Claude

The plugin watches state files and also triggers alerts:

```
Claude CLI → state-hook.sh → state file → statusline.lua → tmux.lua → tmux
```

Both paths work - the shell hook provides alerts for standalone usage, while Lua provides redundant coverage for Neovim.

### Alert Clearing

Alerts clear automatically via multiple mechanisms:

1. **Tmux hooks** - Registered by `tmux.setup()`:
   - `after-select-window` - Keyboard navigation
   - `session-window-changed` - Mouse clicks

2. **FocusGained** - Neovim autocmd when editor gains focus

3. **SessionEnd** - Hook clears alert when Claude session ends

## Configuration

The plugin auto-configures tmux on startup (`tmux.setup()`):

```lua
-- Automatically done by the plugin:
-- 1. Enables focus-events (required for FocusGained)
tmux set-option -g focus-events on

-- 2. Registers window-switch hooks
tmux set-hook -g after-select-window 'if-shell ...'
tmux set-hook -g session-window-changed 'if-shell ...'
```

No manual tmux.conf changes required.

## Catppuccin Mocha Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Yellow | #f9e2af | Processing |
| Peach/Orange | #fab387 | Waiting |
| Green | #a6e3a1 | Done |
| Surface1 | #45475a | Background |

## Troubleshooting

### Alerts not appearing

1. Ensure you're running inside tmux (`echo $TMUX`)
2. Check hook is installed: `ls ~/.claude/hooks/state-hook.sh`
3. Verify hook has tmux functions: `grep tmux_alert ~/.claude/hooks/state-hook.sh`

### Alerts not clearing

1. Check focus-events: `tmux show-options -g focus-events` (should be "on")
2. Check hooks registered: `tmux show-hooks -g | grep @alert`
3. Restart Neovim to re-register hooks

### Testing alerts manually

```vim
:Claude tmux processing  " Yellow alert
:Claude tmux waiting     " Orange alert
:Claude tmux done        " Green alert
:Claude tmux clear       " Clear alert
:Claude tmux debug       " Show debug info
```
