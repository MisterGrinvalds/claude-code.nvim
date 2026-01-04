# Claude Code Neovim Plugin - Agent Instructions

## Overview

**claude-code.nvim** is a Neovim plugin that integrates the Claude Code CLI with Neovim, providing:
- Multi-session terminal management in floating windows
- Real-time statusline with model, tokens, and state
- Automatic buffer synchronization (save before send, refresh after Claude writes)
- Context injection (files, selections, diagnostics)
- Code block extraction and replacement
- Tmux window alerts on state changes

## Project Structure

```
claude-code.nvim/
├── lua/claude-code/           # Core Lua modules
│   ├── init.lua              # Main API, setup(), module loading
│   ├── command.lua           # Unified :Claude command dispatcher
│   ├── session.lua           # Terminal session lifecycle
│   ├── window.lua            # Floating window management
│   ├── state.lua             # State machine (idle/processing/waiting/done)
│   ├── statusline.lua        # Real-time status with fs_event watcher
│   ├── sync.lua              # Buffer save/refresh logic
│   ├── picker.lua            # Telescope session picker
│   └── tmux.lua              # Tmux window alerts
├── plugin/
│   └── claude-code.lua       # Plugin loader (version check, guard)
├── config/
│   ├── hooks/
│   │   └── state-hook.sh     # Unified hook for all Claude events
│   ├── install.sh            # Installation script
│   ├── statusline-bridge.sh  # Status JSON formatter
│   └── settings.json         # Default Claude Code CLI config
├── docs/
│   ├── state-machine.md      # State flow documentation
│   └── buffer-sync.md        # Sync architecture
├── Makefile                  # Development install/uninstall
└── README.md                 # User documentation
```

## Key Modules

### init.lua (Main Entry Point)
- `setup(opts)` - Initialize plugin with user config
- `toggle()` / `toggle_session(name)` - Show/hide Claude window
- `send_file()`, `send_selection()`, `send_diagnostics()`, `ask()` - Context injection
- `extract_code_blocks()`, `replace_with_claude()` - Code extraction
- `install_hooks(force)` - Install CLI hooks

### command.lua (Unified Command API)
Provides `:Claude <subcommand>` pattern similar to Telescope:
- `register(name, fn, desc, complete)` - Register a subcommand
- `run(cmd, args)` - Dispatch to subcommand
- `complete(arg_lead, cmd_line, cursor_pos)` - Tab completion
- `list()` - Get sorted subcommand names

**Available subcommands:**
| Command | Description |
|---------|-------------|
| `:Claude` | Toggle window (default) |
| `:Claude toggle` | Toggle window |
| `:Claude new [name]` | Create session |
| `:Claude delete [name]` | Delete session |
| `:Claude picker` | Session picker |
| `:Claude install` | Install hooks |
| `:Claude file` | Send file |
| `:Claude selection` | Send selection |
| `:Claude diagnostics` | Send diagnostics |
| `:Claude ask` | Custom prompt |
| `:Claude replace` | Replace with code |
| `:Claude status` | Show status |

### session.lua (Terminal Sessions)
- Manages multiple named Claude CLI instances
- Each session: buffer, job_id, state, timestamps
- `create_session(name)`, `delete_session(name)`, `send_to_session(name, text)`

### window.lua (Floating Window)
- Single shared floating window (90% screen, rounded border)
- Title shows session name and state: `Claude Code: main [processing]`
- `show_session(name)`, `hide_window()`, `toggle(name)`

### state.lua (State Machine)
- States: `idle` → `processing` → `waiting` → `done`
- Triggers buffer sync on state transitions
- 60-second timeout recovery for stuck states

### statusline.lua (Real-Time Status)
- Watches `.claude/` directory with `fs_event` (~40ms latency)
- Reads `status.json` (model, tokens, lines) and `state*.json`
- Provides `get_status()`, `get_icon()`, `get_color()` for lualine
- State icons: idle (󰚩), processing (󰦖), waiting (󰋗), done (󰄬)

### sync.lua (Buffer Synchronization)
- **Outbound**: `save_modified_buffers()` before sending context
- **Inbound**: Polls `refresh` file, triggers `checktime` for reloads

### picker.lua (Session Browser)
- Telescope picker sorted by last_used
- Actions: switch (Enter), delete (Ctrl-X), new (Ctrl-N), rename (Ctrl-R)

## Hook System

The plugin communicates with Claude Code CLI via hooks in `~/.claude/hooks/`.

### Hook Events → State Changes

| Event | File Written | State |
|-------|--------------|-------|
| SessionStart | `state-{ID}.json` | idle |
| UserPromptSubmit | `state-{ID}.json` | processing |
| PermissionRequest | `state-{ID}.json` | waiting |
| PostToolUse (Write/Edit) | `refresh-{ID}` | (triggers buffer reload) |
| Stop | `state-{ID}.json` | done |
| SessionEnd | (deletes files) | (cleanup) |

### State Files

- `.claude/state-{SESSION_ID}.json` - Current state
- `.claude/status.json` - Model, tokens, cost, lines changed
- `.claude/refresh-{SESSION_ID}` - Timestamp for buffer refresh

## Development Workflow

### Installation for Development

```bash
# Symlink hooks to ~/.claude for live development
make install

# Check symlink status
make status

# Remove symlinks
make uninstall
```

### Testing Checklist

1. **Fresh install**: `make install` should create symlinks
2. **Settings merge**: Existing `settings.json` should preserve user config
3. **State transitions**: Verify idle → processing → waiting → done
4. **Buffer sync**: Files should save before send, reload after Claude writes
5. **Session cleanup**: Buffers deleted when Claude exits
6. **Multi-session**: Multiple sessions should have independent state

### Making Changes

- **New command**: Add `M.register()` call in `command.lua` setup()
- **New API function**: Add to `init.lua`, expose in returned module table
- **State changes**: Modify `state.lua`, update statusline if needed
- **Hook behavior**: Edit `config/hooks/state-hook.sh`
- **Window behavior**: Modify `window.lua`
- **New keymaps**: Add to `setup_keymaps()` in `session.lua`

## Code Conventions

- Use `vim.schedule()` for deferred operations in callbacks
- Use `pcall()` for operations that may fail (file I/O, JSON parsing)
- Session state managed centrally in `session.lua`
- Window state managed centrally in `window.lua`
- All file paths use `vim.fn.expand()` for tilde expansion
- Logging with `vim.notify()` for user-facing messages

## Common Issues

### E95: Buffer name already exists
- Session cleanup must delete buffer before name can be reused
- Fixed by checking job status before buffer deletion

### State stuck on "waiting"
- 60-second timeout in statusline resets to idle
- Check hook script permissions (`chmod +x`)

### Hooks not firing
- Verify `~/.claude/hooks/state-hook.sh` exists and is executable
- Check `settings.json` has correct hook configuration
- Restart Claude Code CLI after installing hooks

## File Dependencies

```
init.lua
  └── requires: session, window, state, sync, statusline, picker, command

command.lua
  └── requires: claude-code (lazy, for accessing API functions)

session.lua
  └── requires: (none, standalone)

window.lua
  └── requires: session

state.lua
  └── requires: sync, statusline

statusline.lua
  └── requires: (none, standalone)

sync.lua
  └── requires: (none, standalone)

picker.lua
  └── requires: session, window (telescope dependency)
```
