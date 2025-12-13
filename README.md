# claude-code.nvim

A Neovim plugin for seamless integration with [Claude Code](https://claude.ai/code) CLI.

Features a toggleable floating window, context injection commands, and a Telescope-powered command palette.

## Features

- **Toggle Window**: Floating or split window running Claude Code CLI
- **Context Injection**: Send files, selections, and LSP diagnostics to Claude
- **Command Palette**: Telescope picker with common AI coding actions
- **Native Commands**: User commands available in command mode (`:ClaudeToggle`, etc.)

## Requirements

- Neovim >= 0.8
- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- Optional: [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for command palette
- Optional: [which-key.nvim](https://github.com/folke/which-key.nvim) for keymap hints

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'YOUR_USERNAME/claude-code.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim', -- optional
  },
  config = function()
    require('claude-code').setup({
      -- your configuration
    })
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'YOUR_USERNAME/claude-code.nvim',
  requires = { 'nvim-telescope/telescope.nvim' },
  config = function()
    require('claude-code').setup()
  end
}
```

## Configuration

```lua
require('claude-code').setup({
  window = {
    position = 'float', -- 'float', 'right', 'left', 'bottom'
    width = 0.4,        -- 40% of screen width
    height = 0.8,       -- 80% of screen height
    border = 'rounded', -- border style
    title = ' Claude Code ',
  },
  keymaps = {
    toggle = '<leader>cc',          -- Toggle Claude Code window
    send_file = '<leader>cf',       -- Send current file
    send_selection = '<leader>cs',  -- Send visual selection
    send_diagnostics = '<leader>cd', -- Send LSP diagnostics
    send_buffer = '<leader>cb',     -- Send buffer with full context
    command_palette = '<leader>cp', -- Open command palette
    ask = '<leader>ca',             -- Ask Claude (prompt input)
  },
  command = 'claude',   -- CLI command to run
  auto_scroll = true,   -- Auto-scroll to bottom on new output
  close_on_exit = true, -- Close window when Claude exits
  start_insert = true,  -- Start in insert mode
})
```

### Disable Keymaps

To disable specific keymaps, set them to `false`:

```lua
require('claude-code').setup({
  keymaps = {
    toggle = '<leader>cc',
    send_file = false, -- disable this keymap
  },
})
```

## Keybindings

| Key | Mode | Action |
|-----|------|--------|
| `<leader>cc` | Normal | Toggle Claude Code window |
| `<leader>cf` | Normal | Send current file to Claude |
| `<leader>cs` | Visual | Send visual selection to Claude |
| `<leader>cd` | Normal | Send LSP diagnostics to Claude |
| `<leader>cb` | Normal | Send buffer with full context |
| `<leader>cp` | Normal | Open command palette |
| `<leader>ca` | Normal | Ask Claude (prompt input) |

## Commands

| Command | Description |
|---------|-------------|
| `:ClaudeToggle` | Toggle the Claude Code window |
| `:ClaudeOpen` | Open the Claude Code window |
| `:ClaudeClose` | Close the Claude Code window |
| `:ClaudeSendFile` | Send current file to Claude |
| `:ClaudeSendDiagnostics` | Send LSP diagnostics to Claude |
| `:ClaudeSendBuffer` | Send buffer with full context |
| `:ClaudeCommands` | Open command palette |
| `:ClaudeAsk [prompt]` | Ask Claude a question |

## Command Palette

The command palette (`<leader>cp` or `:ClaudeCommands`) includes:

- Toggle Claude Code
- Send Current File
- Send Selection
- Send Diagnostics
- Send Buffer with Context
- Ask: Explain this code
- Ask: Find bugs
- Ask: Optimize
- Ask: Add tests
- Ask: Refactor
- Ask: Add documentation

## API

You can also use the plugin programmatically:

```lua
local claude = require('claude-code')

-- Toggle window
claude.toggle()

-- Open/close
claude.open()
claude.close()

-- Send text
claude.send("Explain this code")

-- Send context
claude.send_file()
claude.send_selection()
claude.send_diagnostics()
claude.send_buffer_context()

-- Get context (returns strings)
local file_ctx = claude.get_file_context()
local selection = claude.get_selection()
local diagnostics = claude.get_diagnostics()
```

## Window Positions

### Float (default)

```
┌────────────────────────────────────────────┐
│                                    ┌──────┐│
│                                    │Claude││
│            Editor                  │Code  ││
│                                    │      ││
│                                    └──────┘│
└────────────────────────────────────────────┘
```

### Right Split

```
┌────────────────────┬───────────────────────┐
│                    │                       │
│      Editor        │     Claude Code       │
│                    │                       │
└────────────────────┴───────────────────────┘
```

### Bottom Split

```
┌────────────────────────────────────────────┐
│                                            │
│                  Editor                    │
│                                            │
├────────────────────────────────────────────┤
│               Claude Code                  │
└────────────────────────────────────────────┘
```

## Integration with Ghostty

When using the [Ghostty workflow](https://danielmiessler.com/blog/claude-code-neovim-ghostty-integration) (left: Claude CLI, right: Neovim), this plugin complements it:

- Use the floating window for quick questions without leaving Neovim
- Use `Ctrl+hjkl` to switch to the Ghostty Claude pane for longer sessions
- Context injection works regardless of which Claude instance you're using

## License

MIT

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
