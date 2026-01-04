# Buffer Synchronization

## The Problem

Neovim buffers and disk files can get out of sync when working with Claude Code:

1. **Outbound**: You edit a buffer but don't save → Claude reads stale disk content
2. **Inbound**: Claude modifies files on disk → Neovim shows stale buffer content

## The Solution

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         OUTBOUND SYNC (You → Claude)                        │
└─────────────────────────────────────────────────────────────────────────────┘

  You editing                                              Claude CLI
  ──────────                                              ──────────
       │                                                       │
       │  (unsaved changes in buffer)                          │
       │                                                       │
       ├──── <leader>cf / <leader>cs / <leader>cd ────────────▶│
       │                                                       │
       │     ┌─────────────────────────┐                       │
       │     │ save_modified_buffers() │                       │
       │     │ - finds all modified    │                       │
       │     │ - writes to disk        │                       │
       │     └─────────────────────────┘                       │
       │                                                       │
       │     [disk now has latest content]                     │
       │                                                       │
       │                                    reads files ───────┤
       │                                    (sees latest!) ────┤
       │                                                       │


┌─────────────────────────────────────────────────────────────────────────────┐
│                         INBOUND SYNC (Claude → You)                         │
└─────────────────────────────────────────────────────────────────────────────┘

  Neovim                     sync.lua                      Claude CLI
  ──────                     ────────                      ──────────
    │                           │                              │
    │                           │         state: processing ───┤
    │                           │◀─────────────────────────────┤
    │                           │                              │
    │                    start_watching()                      │
    │                    (sets needs_refresh=true)             │
    │                           │                              │
    │                           │              writes files ───┤
    │                           │                              │
    │                           │         state: waiting ──────┤
    │                           │◀─────────────────────────────┤
    │                           │                              │
    │◀─── refresh_buffers() ────┤                              │
    │     (checktime)           │                              │
    │                           │                              │
    │  [buffers reload]         │                              │
    │                           │                              │
```

**Note**: We don't poll during processing to avoid screen flickering. Instead, we
do a single `checktime` when Claude finishes. Use `<leader>cb` for manual refresh
if you need to see changes mid-processing.

## Key Components

### `sync.lua`

| Function | Purpose |
|----------|---------|
| `save_modified_buffers()` | Saves all unsaved buffers before sending context |
| `start_watching()` | Marks that refresh is needed when Claude finishes |
| `stop_watching()` | No-op (kept for API compatibility) |
| `refresh_buffers()` | Runs `:checktime` if refresh is pending |
| `force_refresh()` | Runs `:checktime` unconditionally (manual trigger) |

### `state.lua` Integration

```lua
-- When Claude starts processing
if new_state == 'processing' then
  sync.start_watching()

-- When Claude finishes
elseif new_state == 'waiting' or new_state == 'idle' then
  sync.stop_watching()
  sync.refresh_buffers()
```

### Required Setting

```lua
-- In init.lua
vim.o.autoread = true  -- Enables automatic reload on checktime
```

## Keybindings

| Key | Action |
|-----|--------|
| `<leader>cb` | Manual buffer refresh (force `:checktime`) |

## Flow Summary

1. **Before send**: Auto-save all modified buffers
2. **During processing**: Mark that refresh is needed (no polling to avoid flicker)
3. **After processing**: Single `:checktime` to reload any changed files
4. **Manual refresh**: `<leader>cb` forces immediate reload
