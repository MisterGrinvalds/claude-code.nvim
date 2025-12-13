-- claude-code.nvim - Claude Code integration for Neovim
-- Toggle-able window with context injection commands
-- https://github.com/YOUR_USERNAME/claude-code.nvim

local M = {}

-- State
M.state = {
  buf = nil,
  win = nil,
  term_job_id = nil,
  is_open = false,
}

-- Default configuration
M.config = {
  window = {
    position = 'right', -- 'float', 'right', 'left', 'bottom'
    width = 0.4, -- percentage of screen (for right/left)
    height = 0.3, -- percentage of screen (for bottom)
    border = 'rounded',
    title = ' Claude Code ',
  },
  keymaps = {
    toggle = '<leader>cc',
    send_file = '<leader>cf',
    send_selection = '<leader>cs',
    send_diagnostics = '<leader>cd',
    send_buffer = '<leader>cb',
    command_palette = '<leader>cp',
    ask = '<leader>ca',
  },
  command = 'claude', -- The CLI command to run
  auto_scroll = true,
  close_on_exit = true,
  start_insert = false, -- Don't start in insert mode (allows : command)
}

-- Create the floating window
local function create_float_win()
  local width = math.floor(vim.o.columns * M.config.window.width)
  local height = math.floor(vim.o.lines * M.config.window.height)
  local col = vim.o.columns - width - 2
  local row = math.floor((vim.o.lines - height) / 2)

  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = M.config.window.border,
    title = M.config.window.title,
    title_pos = 'center',
  }

  return vim.api.nvim_open_win(M.state.buf, true, opts)
end

-- Create a split window
local function create_split_win()
  local pos = M.config.window.position
  if pos == 'right' then
    vim.cmd('vsplit')
    vim.cmd('wincmd L')
    local width = math.floor(vim.o.columns * M.config.window.width)
    vim.cmd('vertical resize ' .. width)
  elseif pos == 'left' then
    vim.cmd('vsplit')
    vim.cmd('wincmd H')
    local width = math.floor(vim.o.columns * M.config.window.width)
    vim.cmd('vertical resize ' .. width)
  elseif pos == 'bottom' then
    vim.cmd('split')
    vim.cmd('wincmd J')
    local height = math.floor(vim.o.lines * M.config.window.height)
    vim.cmd('resize ' .. height)
  end
  return vim.api.nvim_get_current_win()
end

-- Create or get buffer
local function get_or_create_buf()
  if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
    return M.state.buf
  end

  M.state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.state.buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.state.buf, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(M.state.buf, 'swapfile', false)
  vim.api.nvim_buf_set_name(M.state.buf, 'claude-code')

  return M.state.buf
end

-- Start the terminal
local function start_terminal()
  if M.state.term_job_id then
    return
  end

  M.state.term_job_id = vim.fn.termopen(M.config.command, {
    on_exit = function()
      M.state.term_job_id = nil
      if M.config.close_on_exit then
        M.close()
      end
    end,
  })

  -- Set up buffer-local keymaps for terminal navigation
  local buf = M.state.buf

  -- Double-Escape to exit terminal mode (single Esc passes to Claude Code)
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { buffer = buf, desc = 'Exit terminal mode' })

  -- Ctrl+] as alternative exit (like vim's built-in)
  vim.keymap.set('t', '<C-]>', '<C-\\><C-n>', { buffer = buf, desc = 'Exit terminal mode' })

  -- Quick command mode
  vim.keymap.set('t', '<C-;>', '<C-\\><C-n>:', { buffer = buf, desc = 'Command mode from terminal' })

  -- Quick toggle from within terminal
  vim.keymap.set('t', '<C-\\><C-c>', function()
    vim.cmd('stopinsert')
    M.toggle()
  end, { buffer = buf, desc = 'Toggle Claude window' })

  -- Enter insert mode for terminal only if configured
  if M.config.start_insert then
    vim.cmd('startinsert')
  end
end

-- Open Claude Code window
function M.open()
  if M.state.is_open then
    -- Focus existing window
    if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
      vim.api.nvim_set_current_win(M.state.win)
      if M.config.start_insert then
        vim.cmd('startinsert')
      end
    end
    return
  end

  get_or_create_buf()

  if M.config.window.position == 'float' then
    M.state.win = create_float_win()
  else
    M.state.win = create_split_win()
  end

  vim.api.nvim_win_set_buf(M.state.win, M.state.buf)
  M.state.is_open = true

  -- Start terminal if not already running
  start_terminal()

  -- Set up autocommand to update state when window closes
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(M.state.win),
    once = true,
    callback = function()
      M.state.is_open = false
      M.state.win = nil
    end,
  })
end

-- Close Claude Code window
function M.close()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end
  M.state.is_open = false
  M.state.win = nil
end

-- Open Claude in current window (replaces current buffer)
function M.open_in_current()
  get_or_create_buf()

  -- Set the buffer in current window
  M.state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.state.win, M.state.buf)
  M.state.is_open = true

  -- Start terminal if not already running
  start_terminal()

  -- Set up autocommand to update state when window closes
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(M.state.win),
    once = true,
    callback = function()
      M.state.is_open = false
      M.state.win = nil
    end,
  })
end

-- Toggle Claude Code window
function M.toggle()
  if M.state.is_open then
    M.close()
  else
    M.open()
  end
end

-- Send text to Claude Code terminal and submit
function M.send(text, submit)
  submit = submit ~= false -- default to true

  if not M.state.term_job_id then
    M.open()
    -- Wait for terminal to fully initialize
    vim.defer_fn(function()
      M.send(text, submit)
    end, 2000)
    return
  end

  -- Focus the terminal window and enter terminal mode
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_set_current_win(M.state.win)
    vim.cmd('startinsert')
  end

  -- Use feedkeys to type into terminal as if user is typing
  vim.schedule(function()
    -- Type the text
    vim.api.nvim_feedkeys(text, 't', false)

    if submit then
      vim.defer_fn(function()
        -- Press Enter
        local cr = vim.api.nvim_replace_termcodes('<CR>', true, false, true)
        vim.api.nvim_feedkeys(cr, 't', false)
      end, 100)
    end
  end)
end

-- Get current file context
function M.get_file_context()
  local filepath = vim.fn.expand('%:p')
  local filename = vim.fn.expand('%:t')
  local filetype = vim.bo.filetype

  if filepath == '' then
    return nil
  end

  return {
    path = filepath,
    name = filename,
    filetype = filetype,
    content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'),
  }
end

-- Get visual selection
function M.get_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  if #lines == 0 then
    return nil
  end

  -- Adjust for partial line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  else
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  end

  return table.concat(lines, '\n')
end

-- Get buffer diagnostics
function M.get_diagnostics()
  local diagnostics = vim.diagnostic.get(0)
  if #diagnostics == 0 then
    return nil
  end

  local result = {}
  for _, diag in ipairs(diagnostics) do
    local severity = vim.diagnostic.severity[diag.severity]
    table.insert(result, string.format('[%s] Line %d: %s', severity, diag.lnum + 1, diag.message))
  end

  return table.concat(result, '\n')
end

-- Send current file to Claude
function M.send_file()
  local ctx = M.get_file_context()
  if not ctx then
    vim.notify('No file open', vim.log.levels.WARN)
    return
  end

  local prompt = string.format('Review this file: %s\n\n```%s\n%s\n```', ctx.path, ctx.filetype, ctx.content)
  M.send(prompt)
end

-- Send visual selection to Claude
function M.send_selection()
  local selection = M.get_selection()
  if not selection then
    vim.notify('No selection', vim.log.levels.WARN)
    return
  end

  local ctx = M.get_file_context()
  local filetype = ctx and ctx.filetype or ''

  local prompt = string.format('Review this code:\n\n```%s\n%s\n```', filetype, selection)
  M.send(prompt)
end

-- Send diagnostics to Claude
function M.send_diagnostics()
  local diags = M.get_diagnostics()
  if not diags then
    vim.notify('No diagnostics', vim.log.levels.INFO)
    return
  end

  local ctx = M.get_file_context()
  local prompt = string.format('Fix these issues in %s:\n\n%s', ctx and ctx.path or 'current file', diags)
  M.send(prompt)
end

-- Send entire buffer with context
function M.send_buffer_context()
  local ctx = M.get_file_context()
  if not ctx then
    vim.notify('No file open', vim.log.levels.WARN)
    return
  end

  local diags = M.get_diagnostics()
  local prompt = string.format('File: %s\nFiletype: %s\n', ctx.path, ctx.filetype)

  if diags then
    prompt = prompt .. '\nDiagnostics:\n' .. diags .. '\n'
  end

  prompt = prompt .. string.format('\nContent:\n```%s\n%s\n```', ctx.filetype, ctx.content)
  M.send(prompt)
end

-- Command palette actions
M.actions = {
  { name = 'Toggle Claude Code', action = function() M.toggle() end },
  { name = 'Send Current File', action = function() M.send_file() end },
  { name = 'Send Selection', action = function() M.send_selection() end },
  { name = 'Send Diagnostics', action = function() M.send_diagnostics() end },
  { name = 'Send Buffer with Context', action = function() M.send_buffer_context() end },
  { name = 'Ask: Explain this code', action = function() M.send('Explain this code') end },
  { name = 'Ask: Find bugs', action = function() M.send('Find bugs in this code') end },
  { name = 'Ask: Optimize', action = function() M.send('Optimize this code for performance') end },
  { name = 'Ask: Add tests', action = function() M.send('Write tests for this code') end },
  { name = 'Ask: Refactor', action = function() M.send('Refactor this code to be more readable') end },
  { name = 'Ask: Add documentation', action = function() M.send('Add documentation to this code') end },
}

-- Command palette via Telescope or vim.ui.select
function M.command_palette()
  -- Try Telescope first
  local ok, telescope = pcall(require, 'telescope.pickers')
  if ok then
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local action_state = require('telescope.actions.state')
    local actions_telescope = require('telescope.actions')

    telescope
      .new({}, {
        prompt_title = 'Claude Code Commands',
        finder = finders.new_table({
          results = M.actions,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.name,
              ordinal = entry.name,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
          actions_telescope.select_default:replace(function()
            actions_telescope.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if selection then
              selection.value.action()
            end
          end)
          return true
        end,
      })
      :find()
  else
    -- Fallback to vim.ui.select
    local names = {}
    for _, a in ipairs(M.actions) do
      table.insert(names, a.name)
    end

    vim.ui.select(names, { prompt = 'Claude Code Commands:' }, function(choice)
      if choice then
        for _, a in ipairs(M.actions) do
          if a.name == choice then
            a.action()
            break
          end
        end
      end
    end)
  end
end

-- Custom prompt input
function M.ask()
  vim.ui.input({ prompt = 'Ask Claude: ' }, function(input)
    if input and input ~= '' then
      M.send(input)
    end
  end)
end

-- Set up keymaps
local function setup_keymaps()
  local km = M.config.keymaps

  if km.toggle then
    vim.keymap.set('n', km.toggle, M.toggle, { desc = 'Toggle [C]laude [C]ode' })
  end
  if km.send_file then
    vim.keymap.set('n', km.send_file, M.send_file, { desc = '[C]laude: Send [F]ile' })
  end
  if km.send_selection then
    vim.keymap.set('v', km.send_selection, M.send_selection, { desc = '[C]laude: Send [S]election' })
  end
  if km.send_diagnostics then
    vim.keymap.set('n', km.send_diagnostics, M.send_diagnostics, { desc = '[C]laude: Send [D]iagnostics' })
  end
  if km.send_buffer then
    vim.keymap.set('n', km.send_buffer, M.send_buffer_context, { desc = '[C]laude: Send [B]uffer Context' })
  end
  if km.command_palette then
    vim.keymap.set('n', km.command_palette, M.command_palette, { desc = '[C]laude: Command [P]alette' })
  end
  if km.ask then
    vim.keymap.set('n', km.ask, M.ask, { desc = '[C]laude: [A]sk' })
  end
end

-- Set up user commands
local function setup_commands()
  vim.api.nvim_create_user_command('ClaudeToggle', M.toggle, { desc = 'Toggle Claude Code window' })
  vim.api.nvim_create_user_command('ClaudeOpen', M.open, { desc = 'Open Claude Code window' })
  vim.api.nvim_create_user_command('ClaudeCurrent', M.open_in_current, { desc = 'Open Claude in current window' })
  vim.api.nvim_create_user_command('ClaudeClose', M.close, { desc = 'Close Claude Code window' })
  vim.api.nvim_create_user_command('ClaudeSendFile', M.send_file, { desc = 'Send current file to Claude' })
  vim.api.nvim_create_user_command('ClaudeSendDiagnostics', M.send_diagnostics, { desc = 'Send diagnostics to Claude' })
  vim.api.nvim_create_user_command('ClaudeSendBuffer', M.send_buffer_context, { desc = 'Send buffer with context to Claude' })
  vim.api.nvim_create_user_command('ClaudeCommands', M.command_palette, { desc = 'Open Claude command palette' })
  vim.api.nvim_create_user_command('ClaudeAsk', function(opts)
    if opts.args and opts.args ~= '' then
      M.send(opts.args)
    else
      M.ask()
    end
  end, { nargs = '?', desc = 'Ask Claude a question' })
end

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  setup_keymaps()
  setup_commands()

  -- Add which-key group if available
  local ok, wk = pcall(require, 'which-key')
  if ok then
    wk.add({
      { '<leader>c', group = '[C]laude Code' },
    })
  end
end

return M
