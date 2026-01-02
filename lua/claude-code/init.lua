-- claude-code.nvim - Multi-instance Claude Code integration for Neovim
-- lazygit-style floating window with status indicators

local M = {}

-- Load sub-modules
M.session = require('claude-code.session')
M.window = require('claude-code.window')
M.state = require('claude-code.state')
M.picker_module = require('claude-code.picker')
M.statusline = require('claude-code.statusline')

-- Default configuration
M.config = {
  window = {
    width = 0.9, -- 90% of screen (lazygit-style)
    height = 0.9,
    border = 'rounded',
  },
  command = 'claude', -- Claude CLI command
  default_session = 'main', -- Auto-created session name
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
  vim.ui.input({ prompt = 'Ask Claude: ' }, function(input)
    if input and input ~= '' then
      M.send(input, session_name)
    end
  end)
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
