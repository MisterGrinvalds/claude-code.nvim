# claude-code.nvim

Neovim integration for [Claude Code](https://claude.ai/code) CLI with multi-session support, real-time status, and automatic buffer synchronization.

## Features

- **Multi-session support** - Run multiple Claude instances with named sessions
- **Lazygit-style floating window** - 90% screen coverage, toggle with a keymap
- **Real-time statusline** - Shows model, tokens, lines changed, and state
- **Automatic buffer sync** - Saves before sending context, refreshes after Claude writes
- **Context injection** - Send files, selections, or diagnostics to Claude
- **Code replacement** - Extract code blocks from Claude and apply to your buffer

## Requirements

- Neovim 0.9+
- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (for session picker)
- [jq](https://stedolan.github.io/jq/) (for statusline bridge)
- A [Nerd Font](https://www.nerdfonts.com/) (for status icons)

## Installation

### Plugin (lazy.nvim)

```lua
{
  'your-username/claude-code.nvim',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  config = function()
    require('claude-code').setup({
      window = {
        width = 0.9,
        height = 0.9,
        border = 'rounded',
      },
      command = 'claude',
      default_session = 'main',
    })
  end,
}
```

### Claude Code Hooks

The plugin includes hooks that integrate with Claude Code CLI for real-time status updates and automatic buffer refresh.

**Install from Neovim:**
```vim
:Claude install
```

**Or from terminal:**
```bash
~/.local/share/nvim/lazy/claude-code.nvim/config/install.sh
```

This installs:
- Status line bridge script (~/.claude/statusline-bridge.sh)
- Hook scripts (~/.claude/hooks/)
- Reference settings (~/.claude/settings.json if none exists)

**Restart Claude Code CLI after installing hooks.**

## Keymaps

Add these to your config:

```lua
-- Toggle Claude window
vim.keymap.set('n', '<leader>cc', function()
  require('claude-code').toggle()
end, { desc = 'Claude Code toggle' })

-- Session management
vim.keymap.set('n', '<leader>cp', function()
  require('claude-code').picker()
end, { desc = 'Claude session picker' })

vim.keymap.set('n', '<leader>cn', function()
  require('claude-code').new_session()
end, { desc = 'Claude new session' })

vim.keymap.set('n', '<leader>cx', function()
  require('claude-code').delete_session()
end, { desc = 'Claude delete session' })

-- Context injection
vim.keymap.set('n', '<leader>cf', function()
  require('claude-code').send_file()
end, { desc = 'Send file to Claude' })

vim.keymap.set('v', '<leader>cs', function()
  require('claude-code').send_selection()
end, { desc = 'Send selection to Claude' })

vim.keymap.set('n', '<leader>cd', function()
  require('claude-code').send_diagnostics()
end, { desc = 'Send diagnostics to Claude' })

vim.keymap.set('n', '<leader>ca', function()
  require('claude-code').ask()
end, { desc = 'Ask Claude' })

-- Code replacement
vim.keymap.set({ 'n', 'v' }, '<leader>cr', function()
  require('claude-code').pick_and_replace()
end, { desc = 'Replace with Claude code' })

-- Manual buffer refresh
vim.keymap.set('n', '<leader>cb', function()
  require('claude-code').sync.force_refresh()
end, { desc = 'Refresh buffers' })
```

## Commands

All commands use a unified `:Claude <subcommand>` pattern with tab completion:

| Command | Description |
|---------|-------------|
| `:Claude` | Toggle Claude window (default) |
| `:Claude toggle` | Toggle Claude window |
| `:Claude new [name]` | Create new session |
| `:Claude delete [name]` | Delete session |
| `:Claude picker` | Open session picker |
| `:Claude install` | Install Claude CLI hooks |
| `:Claude install --force` | Force reinstall hooks |
| `:Claude file` | Send current file to Claude |
| `:Claude selection` | Send selection to Claude |
| `:Claude diagnostics` | Send diagnostics to Claude |
| `:Claude ask` | Ask Claude a question |
| `:Claude replace` | Replace with Claude code block |
| `:Claude status` | Show session status |

## Statusline Integration

### Lualine

```lua
{
  'nvim-lualine/lualine.nvim',
  opts = {
    sections = {
      lualine_x = {
        {
          function()
            local ok, statusline = pcall(require, 'claude-code.statusline')
            if ok then return statusline.get_status() end
            return ''
          end,
          color = function()
            local ok, statusline = pcall(require, 'claude-code.statusline')
            if ok then return { fg = statusline.get_color() } end
            return {}
          end,
          cond = function()
            local ok, statusline = pcall(require, 'claude-code.statusline')
            return ok and statusline.get_cached_status() ~= nil
          end,
        },
      },
    },
  },
}
```

### Status States

| State | Icon | Color | When |
|-------|------|-------|------|
| idle | 󰚩 | Gray | No activity |
| processing | 󰦖 | Yellow | Claude is working |
| waiting | 󰋗 | Peach | Needs user input/permission |
| done | 󰄬 | Green | Task complete (3s) |

## How It Works

### Hook Flow

```
UserPromptSubmit ──────────────▶ "processing"
        ↓
PreToolUse ─────────────────────▶ "processing"
        ↓
Notification(permission_prompt) ─▶ "waiting"
        ↓
   [User approves]
        ↓
PreToolUse ─────────────────────▶ "processing"
        ↓
PostToolUse(Write|Edit) ────────▶ buffer refresh
        ↓
Stop ───────────────────────────▶ "done"
```

### Buffer Synchronization

1. **Before sending context**: Auto-saves all modified buffers
2. **After Claude writes**: PostToolUse hook triggers :checktime
3. **Manual refresh**: <leader>cb or :lua require('claude-code').sync.force_refresh()

## Configuration

```lua
require('claude-code').setup({
  window = {
    width = 0.9,      -- 90% of screen
    height = 0.9,
    border = 'rounded',
  },
  command = 'claude', -- CLI command
  default_session = 'main',
  statusline = {
    show_model = true,   -- Show "Opus", "Sonnet"
    show_tokens = true,  -- Show token count
    show_cost = false,   -- Show cost (off by default)
    show_lines = true,   -- Show +added/-removed
  },
})
```

## License

MIT
