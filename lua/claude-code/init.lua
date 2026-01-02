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

return M
