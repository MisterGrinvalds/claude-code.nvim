# Hook System Guide

Understanding and modifying the Claude Code CLI hook integration.

## Overview

Claude Code CLI fires hooks at various lifecycle events. This plugin uses hooks to:
1. Track Claude's current state (idle/processing/waiting/done)
2. Signal when buffers need refreshing (after file writes)
3. Provide statusline data (model, tokens, lines changed)

## Hook Architecture

```
Claude Code CLI
    ↓ fires event
state-hook.sh (unified handler)
    ↓ writes JSON
~/.claude/state-{SESSION}.json
    ↓ fs_event triggers
statusline.lua reads file
    ↓ updates
Neovim statusline
```

## Available Hook Events

| Event | When Fired | Plugin Usage |
|-------|------------|--------------|
| SessionStart | Claude CLI starts | Create state file (idle) |
| SessionEnd | Claude CLI exits | Delete state files |
| UserPromptSubmit | User presses Enter | Set processing state |
| PreToolUse | Before tool execution | (not used) |
| PostToolUse | After tool execution | Trigger buffer refresh on Write/Edit |
| PermissionRequest | Claude asks permission | Set waiting state |
| Stop | Claude stops working | Set done state |
| SubagentStop | Subagent finishes | (not used) |

## Hook Script Details

### Location

- Development: `config/hooks/state-hook.sh` (symlinked to `~/.claude/hooks/`)
- Production: `~/.claude/hooks/state-hook.sh` (copied during install)

### Script Structure

```bash
#!/bin/bash

hook="$1"           # Event name
tool="$2"           # Tool name (for tool events)
cwd="${CWD:-$PWD}"  # Working directory

# Session-specific state file
session_id="${CLAUDE_SESSION_ID:-default}"
state_file="$cwd/.claude/state-${session_id}.json"
refresh_file="$cwd/.claude/refresh-${session_id}"

case "$hook" in
    SessionStart)
        mkdir -p "$cwd/.claude"
        echo '{"state": "idle"}' > "$state_file"
        ;;

    UserPromptSubmit)
        echo '{"state": "processing"}' > "$state_file"
        ;;

    PermissionRequest)
        echo '{"state": "waiting"}' > "$state_file"
        ;;

    PostToolUse)
        # Trigger buffer refresh for file operations
        if [[ "$tool" == "Write" || "$tool" == "Edit" ]]; then
            date +%s > "$refresh_file"
        fi
        ;;

    Stop)
        echo '{"state": "done"}' > "$state_file"
        ;;

    SessionEnd)
        rm -f "$state_file" "$refresh_file"
        ;;
esac
```

## State Files

### state-{SESSION_ID}.json

```json
{"state": "processing"}
```

States: `idle`, `processing`, `waiting`, `done`

### refresh-{SESSION_ID}

Contains Unix timestamp. Presence/modification triggers buffer reload.

### status.json

Written by `statusline-bridge.sh` (if configured):
```json
{
  "model": "claude-sonnet-4-20250514",
  "tokens": 12345,
  "cost": 0.05,
  "lines_added": 42,
  "lines_removed": 10
}
```

## Modifying Hooks

### Adding a New Event Handler

1. Edit `config/hooks/state-hook.sh`:
```bash
YourEvent)
    # Your logic
    echo '{"state": "your_state", "extra": "data"}' > "$state_file"
    ;;
```

2. Register in `config/settings.json`:
```json
{
  "hooks": {
    "YourEvent": ["~/.claude/hooks/state-hook.sh"]
  }
}
```

3. Reinstall: `make install`

4. Restart Claude CLI

### Adding Custom Data

You can add any JSON fields to state files:
```bash
echo '{"state": "processing", "tool": "'"$tool"'", "timestamp": '$(date +%s)'}' > "$state_file"
```

Then read in Lua:
```lua
local data = require('claude-code.statusline').read_state()
if data then
    print(data.tool)
end
```

## Hook Configuration

### settings.json

Located at `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": ["~/.claude/hooks/state-hook.sh"],
    "SessionEnd": ["~/.claude/hooks/state-hook.sh"],
    "UserPromptSubmit": ["~/.claude/hooks/state-hook.sh"],
    "PostToolUse": ["~/.claude/hooks/state-hook.sh"],
    "PermissionRequest": ["~/.claude/hooks/state-hook.sh"],
    "Stop": ["~/.claude/hooks/state-hook.sh"]
  }
}
```

### Hook Arguments

Hooks receive arguments based on event type:

| Event | $1 | $2 | $3+ |
|-------|----|----|-----|
| SessionStart | "SessionStart" | - | - |
| UserPromptSubmit | "UserPromptSubmit" | - | - |
| PreToolUse | "PreToolUse" | tool_name | tool_input |
| PostToolUse | "PostToolUse" | tool_name | tool_result |
| PermissionRequest | "PermissionRequest" | permission_type | - |
| Stop | "Stop" | - | - |
| SessionEnd | "SessionEnd" | - | - |

### Environment Variables

Available in hook scripts:
- `CLAUDE_SESSION_ID` - Unique session identifier
- `CWD` - Claude's working directory
- `PWD` - Current directory (fallback)

## Debugging Hooks

### Test Manually

```bash
# Simulate event
~/.claude/hooks/state-hook.sh UserPromptSubmit
cat ~/.claude/state*.json

# With tool name
~/.claude/hooks/state-hook.sh PostToolUse Write
cat ~/.claude/refresh*
```

### Add Logging

```bash
# At top of state-hook.sh
exec >> /tmp/claude-hooks.log 2>&1
echo "$(date): hook=$1 tool=$2 session=$CLAUDE_SESSION_ID"
```

### Watch Changes

```bash
# Terminal 1: Watch state files
watch -n 0.5 'cat ~/.claude/state*.json 2>/dev/null'

# Terminal 2: Use Claude normally
```

## Multiple Hooks

You can chain multiple scripts:

```json
{
  "hooks": {
    "PostToolUse": [
      "~/.claude/hooks/state-hook.sh",
      "~/.claude/hooks/custom-logger.sh"
    ]
  }
}
```

Scripts execute in order. Non-zero exit from any script is logged but doesn't stop others.

## Project-Local Hooks

State files are written to project-local `.claude/` directory:
- Allows multiple Claude instances in different projects
- Each has independent state tracking
- Files are git-ignored (add `.claude/` to `.gitignore`)

## Troubleshooting

### Hooks Not Firing

1. Check script is executable:
   ```bash
   chmod +x ~/.claude/hooks/state-hook.sh
   ```

2. Check settings.json has hook registered

3. Restart Claude CLI after changes

### State File Not Created

1. Check directory exists: `mkdir -p .claude`
2. Check write permissions
3. Verify `$CWD` or `$PWD` is correct

### Wrong Session ID

The `CLAUDE_SESSION_ID` environment variable must be set by Claude CLI.
If missing, falls back to "default".
