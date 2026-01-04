-- Claude Code tmux integration
-- Provides window alerts when Claude state changes

local M = {}

-- Catppuccin Mocha colors
M.colors = {
  high = '#f38ba8',    -- red - errors
  medium = '#f9e2af',  -- yellow - needs attention
  low = '#94e2d5',     -- teal - success/complete
}

--- Check if running inside tmux
---@return boolean
function M.is_tmux()
  return os.getenv('TMUX') ~= nil
end

--- Get current tmux window ID
---@return string|nil
function M.get_window_id()
  if not M.is_tmux() then
    return nil
  end
  local handle = io.popen("tmux display-message -p '#{window_id}' 2>/dev/null")
  if not handle then
    return nil
  end
  local result = handle:read('*a')
  handle:close()
  return result and result:gsub('%s+', '') or nil
end

--- Set tmux window alert with color
---@param color string|nil Hex color (default: teal)
function M.alert(color)
  if not M.is_tmux() then
    return
  end

  color = color or M.colors.low
  local window_id = M.get_window_id()
  if not window_id then
    return
  end

  -- Set alert flag and style
  vim.fn.system(string.format("tmux set-window-option -t %s @alert 1 2>/dev/null", window_id))
  vim.fn.system(string.format("tmux set-window-option -t %s window-status-style 'fg=%s,bold,bg=#45475a' 2>/dev/null", window_id, color))
end

--- Alert: task complete (teal)
function M.alert_low()
  M.alert(M.colors.low)
end

--- Alert: needs attention (yellow)
function M.alert_medium()
  M.alert(M.colors.medium)
end

--- Alert: error/failure (red)
function M.alert_high()
  M.alert(M.colors.high)
end

--- Trigger alert based on Claude state
---@param state string 'idle'|'processing'|'waiting'|'done'
function M.on_state_change(state)
  if state == 'done' then
    M.alert_low()  -- teal - task complete
  elseif state == 'waiting' then
    M.alert_medium()  -- yellow - needs attention
  end
end

return M
