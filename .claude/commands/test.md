# Test the Plugin

Run through this testing checklist for claude-code.nvim to verify functionality.

## Pre-Test Setup

1. Ensure hooks are installed:
   ```bash
   make install
   make status  # Verify symlinks exist
   ```

2. Restart Claude Code CLI if hooks were just installed

3. Open Neovim with the plugin configured

## Testing Checklist

### Installation & Setup
- [ ] `make install` creates symlinks without errors
- [ ] `make status` shows correct symlink paths
- [ ] `:ClaudeInstallHooks` works from within Neovim
- [ ] `settings.json` merge preserves existing user configuration

### Basic Functionality
- [ ] `:ClaudeToggle` opens floating window
- [ ] `:ClaudeToggle` again closes the window
- [ ] Window is 90% of screen, centered, rounded border
- [ ] Terminal starts with Claude CLI prompt

### Session Management
- [ ] `:ClaudeNew test` creates a new session
- [ ] `:ClaudePicker` shows both sessions
- [ ] Can switch between sessions with Enter
- [ ] `:ClaudeDelete test` removes the session
- [ ] Session picker shows last_used ordering

### State Transitions
- [ ] Statusline shows idle state (󰚩) when Claude is waiting
- [ ] Submitting a prompt shows processing state (󰦖)
- [ ] Permission prompt shows waiting state (󰋗)
- [ ] After completion shows done state (󰄬) briefly
- [ ] State returns to idle after done

### Buffer Synchronization
- [ ] Modified buffers are saved before `send_file()`
- [ ] Modified buffers are saved before `send_selection()`
- [ ] Buffers reload automatically when Claude writes files
- [ ] `:checktime` is triggered after file modifications

### Context Injection
- [ ] `<leader>cf` sends current file to Claude
- [ ] `<leader>cs` sends visual selection
- [ ] `<leader>cd` sends diagnostics
- [ ] `<leader>ca` prompts for question

### Code Blocks
- [ ] `extract_code_blocks()` parses Claude's response
- [ ] `replace_with_claude()` replaces selection with code
- [ ] Multiple code blocks can be picked

### Statusline Integration
- [ ] Lualine shows Claude status when active
- [ ] Model name displays correctly
- [ ] Token count updates
- [ ] Lines changed shows after file writes

### Edge Cases
- [ ] Multiple sessions can run with independent state
- [ ] Closing Claude CLI cleans up session properly
- [ ] No E95 buffer name errors on session recreation
- [ ] 60-second timeout recovers stuck waiting state
- [ ] Rapid state changes don't cause issues

## Performance Checks

- [ ] fs_event watcher has low latency (~40ms)
- [ ] No lag when switching between sessions
- [ ] Status updates don't cause flicker

## Cleanup

After testing:
```bash
# Only if you want to remove development symlinks
make uninstall
```

## Reporting Issues

If a test fails:
1. Check `:messages` for Neovim errors
2. Check `~/.claude/` for state files
3. Verify hook script permissions: `ls -la ~/.claude/hooks/`
4. Test hook manually: `~/.claude/hooks/state-hook.sh PreToolUse`
