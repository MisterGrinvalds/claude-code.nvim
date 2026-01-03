# Extend the Plugin

Guide for adding new features to claude-code.nvim.

## Architecture Overview

The plugin follows a modular architecture:

```
init.lua (API layer)
    ↓ calls
session.lua (terminal management)
window.lua (display)
state.lua (state machine)
sync.lua (buffer sync)
statusline.lua (status display)
picker.lua (telescope UI)
```

## Adding a New API Function

### 1. Add to init.lua

```lua
-- In lua/claude-code/init.lua
function M.your_new_function(opts)
    -- Implementation
    -- Use M.session, M.window, etc. for internal modules
end
```

### 2. Export in Module Table

The function is automatically available since init.lua returns M.

### 3. Add Command (Optional)

```lua
-- In create_commands()
vim.api.nvim_create_user_command('ClaudeYourCommand', function(opts)
    M.your_new_function({ arg = opts.args })
end, { nargs = '?', desc = 'Description' })
```

### 4. Add Keymap (Optional)

```lua
-- In setup_keymaps()
vim.keymap.set('n', '<leader>cy', M.your_new_function, { desc = 'Your function' })
```

## Adding a New State

### 1. Update state.lua

```lua
-- Add new state handler
function M.set_your_state(name)
    local session = require('claude-code.session')
    session.update_state(name, 'your_state')
    -- Trigger any side effects
end
```

### 2. Update statusline.lua

```lua
-- Add icon and color
local state_icons = {
    idle = '󰚩',
    processing = '󰦖',
    waiting = '󰋗',
    done = '󰄬',
    your_state = '󰊕',  -- Choose appropriate Nerd Font icon
}

local state_colors = {
    idle = '#6c7086',
    processing = '#f9e2af',
    waiting = '#fab387',
    done = '#a6e3a1',
    your_state = '#89b4fa',
}
```

### 3. Update Hook Script (if triggered by Claude)

```bash
# In config/hooks/state-hook.sh
case "$hook" in
    YourHookEvent)
        echo '{"state": "your_state"}' > "$state_file"
        ;;
esac
```

## Adding a New Hook Event

### 1. Identify the Claude Code Event

Available events: SessionStart, SessionEnd, UserPromptSubmit, PreToolUse, PostToolUse, PermissionRequest, Stop, SubagentStop

### 2. Handle in state-hook.sh

```bash
# In config/hooks/state-hook.sh
YourEvent)
    # Your logic here
    echo '{"state": "processing"}' > "$state_file"
    ;;
```

### 3. Register in settings.json

```json
{
  "hooks": {
    "YourEvent": ["~/.claude/hooks/state-hook.sh"]
  }
}
```

## Adding a New Module

### 1. Create the Module File

```lua
-- lua/claude-code/yourmodule.lua
local M = {}

function M.setup(opts)
    -- Initialization
end

function M.some_function()
    -- Implementation
end

return M
```

### 2. Require in init.lua

```lua
-- At top of init.lua
M.yourmodule = require('claude-code.yourmodule')

-- In setup()
M.yourmodule.setup(config.yourmodule)
```

### 3. Add Config Options

```lua
-- In M.config defaults
M.config = {
    -- existing options...
    yourmodule = {
        enabled = true,
        option1 = 'default',
    },
}
```

## Adding Statusline Data

### 1. Write Data from Hook

```bash
# In state-hook.sh or new script
echo '{"your_data": "value"}' > ~/.claude/your_data.json
```

### 2. Read in statusline.lua

```lua
function M.read_your_data()
    local path = vim.fn.expand('~/.claude/your_data.json')
    local file = io.open(path, 'r')
    if not file then return nil end
    local content = file:read('*a')
    file:close()
    local ok, data = pcall(vim.json.decode, content)
    return ok and data or nil
end
```

### 3. Add Watcher Pattern

The existing fs_event watcher in statusline.lua watches `~/.claude/`.
Files there are automatically detected.

## Adding Telescope Actions

### 1. Update picker.lua

```lua
-- In attach_mappings
map('i', '<C-y>', function(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    actions.close(prompt_bufnr)
    -- Your action with selection.value (session name)
end)
```

## Testing Your Changes

1. Make your changes
2. Reload plugin: `:source lua/claude-code/init.lua` or restart Neovim
3. Run `/test` checklist
4. Test edge cases specific to your feature

## Code Style

- Use `vim.schedule()` for deferred UI operations
- Use `pcall()` for operations that may fail
- Use `vim.notify()` for user messages
- Keep state in appropriate modules (session state in session.lua, etc.)
- Document public functions with comments
