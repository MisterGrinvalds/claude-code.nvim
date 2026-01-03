# Debug the Plugin

Troubleshooting guide for claude-code.nvim issues.

## Quick Diagnostics

### Check Plugin Status

```vim
" Verify plugin loaded
:echo exists('g:loaded_claude_code')

" Check if setup was called
:lua print(vim.inspect(require('claude-code').config))

" List registered commands
:command Claude
```

### Check Hook Installation

```bash
# Verify hooks exist
ls -la ~/.claude/hooks/

# Check permissions
stat ~/.claude/hooks/state-hook.sh

# Verify symlinks (for development)
make status
```

### Check State Files

```bash
# View current state
cat ~/.claude/state*.json

# View status data
cat ~/.claude/status.json

# Check refresh signals
ls -la ~/.claude/refresh*
```

## Common Issues

### Window Doesn't Open

**Symptoms**: `:ClaudeToggle` does nothing

**Debug**:
```vim
:lua print(vim.inspect(require('claude-code.session').list_sessions()))
:lua print(require('claude-code.window').is_visible())
```

**Causes**:
- Session creation failed (check `:messages`)
- Claude command not found (verify `which claude`)
- Buffer creation error

### State Not Updating

**Symptoms**: Statusline stuck on one state

**Debug**:
```bash
# Check if hooks are firing
tail -f ~/.claude/state*.json

# Test hook manually
~/.claude/hooks/state-hook.sh PreToolUse
cat ~/.claude/state*.json
```

**Causes**:
- Hook script not executable: `chmod +x ~/.claude/hooks/state-hook.sh`
- Hook not registered in settings.json
- Claude CLI needs restart after hook changes

### E95: Buffer Name Already Exists

**Symptoms**: Error when recreating session

**Debug**:
```vim
:ls!  " List all buffers including unlisted
:lua print(vim.inspect(require('claude-code.session').get_session('main')))
```

**Causes**:
- Session cleanup didn't delete buffer properly
- Race condition on rapid session creation/deletion

**Fix**: Restart Neovim or manually delete the buffer:
```vim
:bwipeout! <buffer_number>
```

### Buffers Not Refreshing

**Symptoms**: Files modified by Claude don't reload

**Debug**:
```vim
:set autoread?  " Should be 'autoread'
:lua print(vim.o.autoread)

" Manual refresh
:checktime
```

**Causes**:
- `autoread` not set
- PostToolUse hook not writing refresh file
- sync.lua watcher not running

**Check watcher**:
```vim
:lua print(require('claude-code.sync').is_watching())
```

### Statusline Not Showing

**Symptoms**: No Claude status in lualine

**Debug**:
```vim
:lua print(require('claude-code.statusline').get_status())
:lua print(require('claude-code.statusline').get_cached_status())
```

**Causes**:
- Lualine not configured with component
- No status.json file exists
- fs_event watcher not started

**Check watcher**:
```vim
:lua print(require('claude-code.statusline').watcher_active())
```

### Permission State Stuck

**Symptoms**: State shows "waiting" forever

**Debug**:
```bash
cat ~/.claude/state*.json
# Check timestamp
stat ~/.claude/state*.json
```

**Causes**:
- User dismissed permission dialog without responding
- Stop hook didn't fire

**Fix**: State auto-recovers after 60 seconds, or:
```vim
:lua require('claude-code.state').set_idle('main')
```

## Logging

### Enable Verbose Logging

Add to your config:
```lua
require('claude-code').setup({
    -- ... other options
    debug = true,  -- If implemented
})
```

### Check Neovim Messages

```vim
:messages
```

### Hook Script Debugging

Add logging to state-hook.sh:
```bash
# At top of script
exec >> /tmp/claude-hook.log 2>&1
echo "$(date): $1 $2"
```

Then:
```bash
tail -f /tmp/claude-hook.log
```

## Module-Specific Debug

### session.lua

```vim
" List all sessions
:lua print(vim.inspect(require('claude-code.session').list_sessions()))

" Check specific session
:lua print(vim.inspect(require('claude-code.session').get_session('main')))

" Check if job is running
:lua local s = require('claude-code.session').get_session('main'); print(s and vim.fn.jobwait({s.job_id}, 0)[1] == -1)
```

### window.lua

```vim
" Check window state
:lua print(require('claude-code.window').is_visible())
:lua print(require('claude-code.window').current_window)
```

### state.lua

```vim
" Check state machine
:lua print(require('claude-code.state').get_state('main'))

" Force state transition
:lua require('claude-code.state').set_idle('main')
```

### statusline.lua

```vim
" Check watcher
:lua print(require('claude-code.statusline').watcher_active())

" Force read
:lua print(vim.inspect(require('claude-code.statusline').read_status()))
:lua print(vim.inspect(require('claude-code.statusline').read_state()))

" Get current display
:lua print(require('claude-code.statusline').get_status())
```

### sync.lua

```vim
" Check watcher
:lua print(require('claude-code.sync').is_watching())

" Force refresh
:lua require('claude-code.sync').force_refresh()
```

## Reset Everything

If all else fails:

```bash
# Remove all state files
rm -rf ~/.claude/state*.json ~/.claude/refresh* ~/.claude/status.json

# Reinstall hooks
make uninstall
make install

# Restart Claude CLI and Neovim
```

## Getting Help

1. Check `:messages` for errors
2. Review state files in `~/.claude/`
3. Check hook script with manual execution
4. File issue at repository with:
   - Neovim version (`:version`)
   - Plugin version (git commit)
   - Relevant error messages
   - Steps to reproduce
