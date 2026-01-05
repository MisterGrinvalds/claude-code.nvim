-- Claude Code tmux integration
-- Provides window alerts when Claude state changes

local M = {}

-- Catppuccin Mocha colors
M.colors = {
  high = '#f38ba8',       -- red - errors
  medium = '#fab387',     -- orange/peach - needs attention (waiting)
  low = '#a6e3a1',        -- green - success/complete
  processing = '#f9e2af', -- yellow - working
  bg = '#45475a',         -- surface1 - background
}

-- Cache for original window formats
M._original_format = nil
M._original_current_format = nil
M._current_window_id = nil

--- Check if running inside tmux
---@return boolean
function M.is_tmux()
  return os.getenv('TMUX') ~= nil
end

--- Get tmux window ID for the window containing this Neovim instance
---@return string|nil
function M.get_window_id()
  if not M.is_tmux() then
    return nil
  end

  -- Use TMUX_PANE to get the window ID for THIS pane, not the focused window
  local pane_id = os.getenv('TMUX_PANE')
  local cmd
  if pane_id then
    cmd = string.format("tmux display-message -p -t %s '#{window_id}' 2>/dev/null", pane_id)
  else
    cmd = "tmux display-message -p '#{window_id}' 2>/dev/null"
  end

  local handle = io.popen(cmd)
  if not handle then
    return nil
  end
  local result = handle:read('*a')
  handle:close()
  return result and result:gsub('%s+', '') or nil
end

--- Get tmux option value from multiple sources (window -> session -> global)
---@param window_id string
---@param option string Option name (e.g., 'window-status-format')
---@return string|nil
local function get_tmux_option(window_id, option)
  local sources = {
    string.format("tmux show-window-options -t %s -v %s 2>/dev/null", window_id, option),
    string.format("tmux show-options -wv %s 2>/dev/null", option),
    string.format("tmux show-options -gv %s 2>/dev/null", option),
  }

  for _, cmd in ipairs(sources) do
    local handle = io.popen(cmd)
    if handle then
      local result = handle:read('*a')
      handle:close()
      if result and result:gsub('%s+', '') ~= '' then
        return result:gsub('%s+$', '')
      end
    end
  end

  return nil
end

--- Save the original window formats for later restoration
---@param window_id string
local function save_original_format(window_id)
  if M._original_format and M._current_window_id == window_id then
    return -- Already saved for this window
  end

  -- Get both inactive and current window formats
  M._original_format = get_tmux_option(window_id, 'window-status-format') or '#I:#W#F'
  M._original_current_format = get_tmux_option(window_id, 'window-status-current-format') or '#I:#W#F'
  M._current_window_id = window_id
end

--- Strip tmux style codes from format string, returning plain content
---@param format string Format string with #[...] codes
---@return string Plain format without style codes
local function strip_style_codes(format)
  -- Remove all #[...] style sequences
  return format:gsub('#%[[^%]]*%]', '')
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

  -- Save original format before modifying
  save_original_format(window_id)

  -- Set alert flag and store original formats in tmux (for clear-alert.sh to access)
  vim.fn.system(string.format("tmux set-window-option -t %s @alert 1 2>/dev/null", window_id))
  vim.fn.system(string.format("tmux set-window-option -t %s @original_format '%s' 2>/dev/null", window_id, M._original_format))
  vim.fn.system(string.format("tmux set-window-option -t %s @original_current_format '%s' 2>/dev/null", window_id, M._original_current_format))

  -- Strip existing style codes and apply our colors (for both inactive and current window)
  local plain_format = strip_style_codes(M._original_format)
  local plain_current_format = strip_style_codes(M._original_current_format)
  local colored_format = string.format('#[fg=%s,bold,bg=%s]%s#[default]', color, M.colors.bg, plain_format)
  local colored_current_format = string.format('#[fg=%s,bold,bg=%s]%s#[default]', color, M.colors.bg, plain_current_format)

  vim.fn.system(string.format("tmux set-window-option -t %s window-status-format '%s' 2>/dev/null", window_id, colored_format))
  vim.fn.system(string.format("tmux set-window-option -t %s window-status-current-format '%s' 2>/dev/null", window_id, colored_current_format))
end

--- Clear tmux window alert, restore original format
function M.clear()
  if not M.is_tmux() then
    return
  end

  local window_id = M.get_window_id()
  if not window_id then
    return
  end

  -- Clear alert flag
  vim.fn.system(string.format("tmux set-window-option -t %s @alert 0 2>/dev/null", window_id))

  -- Unset window-specific formats to fall back to global/session settings
  vim.fn.system(string.format("tmux set-window-option -t %s -u window-status-format 2>/dev/null", window_id))
  vim.fn.system(string.format("tmux set-window-option -t %s -u window-status-current-format 2>/dev/null", window_id))

  -- Clean up stored original formats
  vim.fn.system(string.format("tmux set-window-option -t %s -u @original_format 2>/dev/null", window_id))
  vim.fn.system(string.format("tmux set-window-option -t %s -u @original_current_format 2>/dev/null", window_id))
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

--- Alert: processing (blue)
function M.alert_processing()
  M.alert(M.colors.processing)
end

--- Trigger alert based on Claude state
---@param state string 'idle'|'processing'|'waiting'|'done'
function M.on_state_change(state)
  if state == 'done' then
    M.alert_low()  -- green - task complete
  elseif state == 'waiting' then
    M.alert_medium()  -- orange - needs attention
  elseif state == 'processing' then
    M.alert_processing()  -- yellow - working
  elseif state == 'idle' then
    M.clear()  -- restore normal
  end
end

return M
