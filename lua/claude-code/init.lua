-- claude-code.nvim - Multi-instance Claude Code integration for Neovim
-- lazygit-style floating window with status indicators

local M = {}

-- Load sub-modules
M.session = require('claude-code.session')
M.window = require('claude-code.window')
M.state = require('claude-code.state')
M.picker_module = require('claude-code.picker')
M.statusline = require('claude-code.statusline')
M.sync = require('claude-code.sync')
M.command = require('claude-code.command')

-- Default configuration
M.config = {
  window = {
    mode = 'float',       -- 'float' or 'split'
    split_side = 'right', -- 'right' or 'left' (for split mode)
    split_width = 0.4,    -- Width fraction for split mode (0.0-1.0)
    width = 0.9,          -- 90% of screen (lazygit-style, for float mode)
    height = 0.9,
    border = 'rounded',
  },
  command = 'claude', -- Claude CLI command
  default_session = 'main', -- Auto-created session name
  statusline = {
    show_model = true,      -- Show model name (Opus, Sonnet)
    show_tokens = true,     -- Show token count
    show_cost = false,      -- Show cost (off by default)
    show_lines = true,      -- Show lines added/removed
    format = nil,           -- Custom format function(status) -> string
  },
}

--- Setup Claude Code
---@param opts table|nil User configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- Set up which-key group
  local ok, wk = pcall(require, 'which-key')
  if ok then
    wk.add({
      { '<leader>c', group = '[C]laude Code' },
    })
  end

  -- Initialize statusline with config (watches status & state files)
  M.statusline.setup(M.config.statusline)

  -- Initialize sync module (watches refresh file for buffer reload)
  M.sync.setup()

  -- Initialize command module
  M.command.setup()

  -- Register unified :Claude command
  vim.api.nvim_create_user_command('Claude', function(opts)
    local args = opts.fargs
    local cmd = args[1]
    local rest = vim.list_slice(args, 2)
    M.command.run(cmd, rest)
  end, {
    nargs = '*',
    complete = function(arg_lead, cmd_line, cursor_pos)
      return M.command.complete(arg_lead, cmd_line, cursor_pos)
    end,
    desc = 'Claude Code commands',
  })
end

--- Toggle Claude window (main/last session)
function M.toggle()
  M.window.toggle()
end

--- Toggle specific Claude session
---@param name string Session name
function M.toggle_session(name)
  M.window.toggle(name)
end

--- Create new Claude session
---@param name string|nil Session name (prompts if nil)
function M.new_session(name)
  if not name then
    vim.ui.input({ prompt = 'Claude session name: ' }, function(input)
      if input and input ~= '' then
        M.session.create_session(input)
        M.window.show_session(input)
      end
    end)
  else
    M.session.create_session(name)
    M.window.show_session(name)
  end
end

--- Show session picker
function M.picker()
  M.picker_module.show()
end

--- Delete a Claude session
---@param name string|nil Session name (prompts if nil)
function M.delete_session(name)
  if not name then
    -- Show picker to select session to delete
    local sessions = M.session.list_sessions()
    if #sessions == 0 then
      vim.notify('No Claude sessions to delete', vim.log.levels.INFO)
      return
    end

    vim.ui.select(sessions, {
      prompt = 'Delete Claude session:',
      format_item = function(session_name)
        local session = M.session.get_session(session_name)
        local state = session and session.state or 'unknown'
        return session_name .. ' (' .. state .. ')'
      end,
    }, function(choice)
      if choice then
        M.session.delete_session(choice)
        vim.notify('Deleted Claude session: ' .. choice, vim.log.levels.INFO)
      end
    end)
  else
    M.session.delete_session(name)
    vim.notify('Deleted Claude session: ' .. name, vim.log.levels.INFO)
  end
end

--- Get current file context
---@return table|nil
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

--- Get visual selection
---@return string|nil
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

--- Get buffer diagnostics
---@return string|nil
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

--- Send text to Claude session
---@param text string Text to send
---@param session_name string|nil Session name (default: current/last/main)
function M.send(text, session_name)
  -- Determine session
  session_name = session_name or M.session.current_session or M.session.last_session or M.config.default_session

  -- Get or create session
  local session = M.session.get_or_create(session_name)

  if not session then
    return
  end

  -- Show session if not visible
  if not session.is_visible then
    M.window.show_session(session_name)
    -- Wait for terminal to be ready
    vim.defer_fn(function()
      M.session.send_to_session(session_name, text, true)
    end, 500)
  else
    M.session.send_to_session(session_name, text, true)
  end
end

--- Send current file to Claude
---@param session_name string|nil
function M.send_file(session_name)
  -- Auto-save modified buffers so Claude sees latest content
  M.sync.save_modified_buffers()

  local ctx = M.get_file_context()
  if not ctx then
    vim.notify('No file open', vim.log.levels.WARN)
    return
  end

  local prompt = string.format('Review this file: %s\n\n```%s\n%s\n```', ctx.path, ctx.filetype, ctx.content)
  M.send(prompt, session_name)
end

--- Send visual selection to Claude
---@param session_name string|nil
function M.send_selection(session_name)
  -- Auto-save modified buffers so Claude sees latest content
  M.sync.save_modified_buffers()

  local selection = M.get_selection()
  if not selection then
    vim.notify('No selection', vim.log.levels.WARN)
    return
  end

  local ctx = M.get_file_context()
  local filetype = ctx and ctx.filetype or ''

  local prompt = string.format('Review this code:\n\n```%s\n%s\n```', filetype, selection)
  M.send(prompt, session_name)
end

--- Send diagnostics to Claude
---@param session_name string|nil
function M.send_diagnostics(session_name)
  -- Auto-save modified buffers so Claude sees latest content
  M.sync.save_modified_buffers()

  local diags = M.get_diagnostics()
  if not diags then
    vim.notify('No diagnostics', vim.log.levels.INFO)
    return
  end

  local ctx = M.get_file_context()
  local prompt = string.format('Fix these issues in %s:\n\n%s', ctx and ctx.path or 'current file', diags)
  M.send(prompt, session_name)
end

--- Custom prompt input
---@param session_name string|nil
function M.ask(session_name)
  -- Auto-save modified buffers so Claude sees latest content
  M.sync.save_modified_buffers()

  vim.ui.input({ prompt = 'Ask Claude: ' }, function(input)
    if input and input ~= '' then
      M.send(input, session_name)
    end
  end)
end

--- Install Claude Code hooks and configuration
---@param force boolean|nil Force overwrite existing files
function M.install_hooks(force)
  -- Find the config directory relative to this plugin
  local source = debug.getinfo(1, 'S').source:sub(2) -- Remove @ prefix
  local plugin_dir = vim.fn.fnamemodify(source, ':h:h:h') -- Go up to plugin root
  local install_script = plugin_dir .. '/config/install.sh'

  if vim.fn.filereadable(install_script) ~= 1 then
    vim.notify('Install script not found: ' .. install_script, vim.log.levels.ERROR)
    return
  end

  local cmd = install_script
  if force then
    cmd = cmd .. ' --force'
  end

  -- Run install script
  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= '' then
          print(line)
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= '' then
          vim.notify(line, vim.log.levels.WARN)
        end
      end
    end,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify('Claude Code hooks installed! Restart Claude CLI to activate.', vim.log.levels.INFO)
      else
        vim.notify('Install failed with code ' .. code, vim.log.levels.ERROR)
      end
    end,
  })
end

--- Get all session states (for debugging)
---@return table
function M.get_status()
  local status = {}
  for name, session in pairs(M.session.sessions) do
    status[name] = {
      state = session.state,
      is_visible = session.is_visible,
      last_active = os.time() - session.last_active .. 's ago',
    }
  end
  return status
end

--- Extract code blocks from Claude's response
---@param session_name string|nil
---@return string[]|nil Array of code blocks
function M.extract_code_blocks(session_name)
  session_name = session_name or M.session.current_session or M.session.last_session or M.config.default_session
  local session = M.session.get_session(session_name)

  if not session or not vim.api.nvim_buf_is_valid(session.buf) then
    return nil
  end

  -- Get all lines from Claude buffer
  local lines = vim.api.nvim_buf_get_lines(session.buf, 0, -1, false)

  local code_blocks = {}
  local in_code_block = false
  local current_block = {}

  for _, line in ipairs(lines) do
    if line:match('^```') then
      if in_code_block then
        -- End of code block
        if #current_block > 0 then
          table.insert(code_blocks, table.concat(current_block, '\n'))
        end
        current_block = {}
        in_code_block = false
      else
        -- Start of code block
        in_code_block = true
      end
    elseif in_code_block then
      table.insert(current_block, line)
    end
  end

  return #code_blocks > 0 and code_blocks or nil
end

--- Replace selection or current line with Claude's code
---@param session_name string|nil
---@param block_index number|nil Which code block to use (default: last)
function M.replace_with_claude(session_name, block_index)
  local blocks = M.extract_code_blocks(session_name)

  if not blocks then
    vim.notify('No code blocks found in Claude response', vim.log.levels.WARN)
    return
  end

  -- Use last block by default
  block_index = block_index or #blocks

  if block_index > #blocks then
    vim.notify('Code block ' .. block_index .. ' not found (only ' .. #blocks .. ' blocks)', vim.log.levels.WARN)
    return
  end

  local code = blocks[block_index]

  -- Create undo point before modifying
  vim.cmd('normal! m`') -- Mark position for `` jump
  local undolevels = vim.o.undolevels
  vim.o.undolevels = undolevels -- Force undo break

  -- Get visual selection range or current line
  local start_line, end_line
  local mode = vim.fn.mode()

  if mode == 'v' or mode == 'V' or mode == '\22' then
    -- Visual mode - use selection
    start_line = vim.fn.line("'<") - 1
    end_line = vim.fn.line("'>")
  else
    -- Normal mode - use current line
    start_line = vim.fn.line('.') - 1
    end_line = start_line + 1
  end

  -- Split code into lines
  local new_lines = vim.split(code, '\n', { plain = true })

  -- Replace selection
  vim.api.nvim_buf_set_lines(0, start_line, end_line, false, new_lines)

  vim.notify(
    string.format('✓ Replaced with Claude code block %d of %d (undo with u, jump back with ``)', block_index, #blocks),
    vim.log.levels.INFO
  )
end

--- Show code block picker (if multiple blocks)
---@param session_name string|nil
function M.pick_and_replace(session_name)
  local blocks = M.extract_code_blocks(session_name)

  if not blocks then
    vim.notify('No code blocks found in Claude response', vim.log.levels.WARN)
    return
  end

  if #blocks == 1 then
    -- Only one block, use it directly
    M.replace_with_claude(session_name, 1)
    return
  end

  -- Multiple blocks - show enhanced picker with line counts
  local formatted_blocks = {}
  for i, block in ipairs(blocks) do
    local line_count = select(2, block:gsub('\n', '\n')) + 1
    local first_line = block:match('^[^\n]+') or block
    local preview = first_line:sub(1, 50) .. (#first_line > 50 and '...' or '')
    formatted_blocks[i] = string.format('[%d lines] %s', line_count, preview)
  end

  vim.ui.select(formatted_blocks, {
    prompt = 'Select code block to insert (' .. #blocks .. ' available):',
  }, function(choice, idx)
    if choice then
      M.replace_with_claude(session_name, idx)
    end
  end)
end

return M
