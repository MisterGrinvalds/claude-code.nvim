-- Claude Code window management
-- Handles floating window creation and session display

local M = {}

-- Shared Claude window reference
M.claude_window = nil

--- Create large floating window (90% x 90%, lazygit-style)
---@param buf number Buffer to show
---@param title string Window title
---@return number Window ID
function M.create_float_window(buf, title)
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    title = title or ' Claude Code ',
    title_pos = 'center',
  }

  return vim.api.nvim_open_win(buf, true, opts)
end

--- Get or create the shared Claude window
---@param buf number Buffer to display
---@param title string Window title
---@return number Window ID
function M.get_or_create_window(buf, title)
  -- Check if window exists and is valid
  if M.claude_window and vim.api.nvim_win_is_valid(M.claude_window) then
    -- Reuse existing window, just switch buffer
    vim.api.nvim_win_set_buf(M.claude_window, buf)
    -- Update title
    vim.api.nvim_win_set_config(M.claude_window, {
      title = title,
    })
    return M.claude_window
  end

  -- Create new floating window
  local win = M.create_float_window(buf, title)
  M.claude_window = win

  -- Set up autocommand to clear reference when window closes
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function()
      M.claude_window = nil
      -- Mark all sessions as not visible
      local session_module = require('claude-code.session')
      for _, session in pairs(session_module.sessions) do
        session.is_visible = false
      end
    end,
  })

  return win
end

--- Show a Claude session
---@param name string Session name
function M.show_session(name)
  local session_module = require('claude-code.session')
  local session = session_module.get_session(name)

  if not session then
    vim.notify('Claude session "' .. name .. '" not found', vim.log.levels.ERROR)
    return
  end

  -- Generate window title with state
  local title = string.format(' Claude Code: %s [%s] ', name, session.state)

  -- Get or create window and show buffer
  local win = M.get_or_create_window(session.buf, title)

  -- Update session state
  session.win = win
  session.is_visible = true
  session.last_used = os.time()
  session_module.current_session = name
  session_module.last_session = name

  -- Focus window and enter insert mode
  vim.api.nvim_set_current_win(win)
  vim.cmd('startinsert')

  -- Notify state manager
  require('claude-code.state').on_show(name)
end

--- Hide the Claude window
function M.hide_window()
  -- Get current session name before closing
  local session_module = require('claude-code.session')
  local current_name = session_module.current_session

  if M.claude_window and vim.api.nvim_win_is_valid(M.claude_window) then
    vim.api.nvim_win_close(M.claude_window, true)
  end
  M.claude_window = nil

  -- Mark all sessions as not visible
  for _, session in pairs(session_module.sessions) do
    session.is_visible = false
  end

  -- Notify state manager (triggers buffer refresh)
  if current_name then
    require('claude-code.state').on_hide(current_name)
  end
end

--- Toggle Claude window (show/hide)
---@param name string|nil Session name (nil = current/last/main)
function M.toggle(name)
  local session_module = require('claude-code.session')

  -- If window is visible, hide it
  if M.claude_window and vim.api.nvim_win_is_valid(M.claude_window) then
    M.hide_window()
    return
  end

  -- Determine which session to show
  local session_name = name or session_module.current_session or session_module.last_session or 'main'

  -- Get or create session
  local session = session_module.get_or_create(session_name)

  if session then
    M.show_session(session_name)
  end
end

--- Check if Claude window is visible
---@return boolean
function M.is_visible()
  return M.claude_window ~= nil and vim.api.nvim_win_is_valid(M.claude_window)
end

--- Update window title (shows session name and state)
---@param name string Session name
---@param state string Session state
function M.update_title(name, state)
  if not M.is_visible() then
    return
  end

  local session_module = require('claude-code.session')
  local session = session_module.get_session(name)

  -- Only update if this session is currently visible
  if session and session.is_visible and M.claude_window then
    local title = string.format(' Claude Code: %s [%s] ', name, state)
    vim.api.nvim_win_set_config(M.claude_window, {
      title = title,
    })
  end
end

return M
