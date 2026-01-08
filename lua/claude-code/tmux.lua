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

--- Check if format contains our alert colors (meaning it's our format, not original)
---@param format string Format string to check
---@return boolean
local function is_our_format(format)
  if not format then
    return false
  end
  -- Check for any of our Catppuccin alert colors
  return format:match('#a6e3a1') or format:match('#f9e2af') or format:match('#fab387') or format:match('#f38ba8')
end

--- Get global tmux option (bypasses window-specific overrides)
---@param option string Option name
---@return string|nil
local function get_global_option(option)
  local cmd = string.format("tmux show-options -gv %s 2>/dev/null", option)
  local handle = io.popen(cmd)
  if handle then
    local result = handle:read('*a')
    handle:close()
    if result and result:gsub('%s+', '') ~= '' then
      return result:gsub('%s+$', '')
    end
  end
  return nil
end

--- Save the original window formats for later restoration
---@param window_id string
local function save_original_format(window_id)
  -- Check cached format - if it's our alert format, we need to refresh from global
  if M._original_format and M._current_window_id == window_id and not is_our_format(M._original_format) then
    return -- Already have valid saved format for this window
  end

  -- Always get from global to ensure we have the real original (not our alert format)
  M._original_format = get_global_option('window-status-format') or '#I:#W#F'
  M._original_current_format = get_global_option('window-status-current-format') or '#I:#W#F'
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

  -- Unset window-specific format overrides (lets global theme take over)
  vim.fn.system(string.format("tmux set-window-option -t %s -u window-status-format 2>/dev/null", window_id))
  vim.fn.system(string.format("tmux set-window-option -t %s -u window-status-current-format 2>/dev/null", window_id))

  -- Unset saved format metadata
  vim.fn.system(string.format("tmux set-window-option -t %s -u @original_format 2>/dev/null", window_id))
  vim.fn.system(string.format("tmux set-window-option -t %s -u @original_current_format 2>/dev/null", window_id))

  -- Reset Lua cache so next alert fetches fresh from global
  M._original_format = nil
  M._original_current_format = nil
  M._current_window_id = nil
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

--- Setup tmux integration
--- Enables focus-events and registers window-switch hooks to clear alerts
function M.setup()
  if not M.is_tmux() then
    return
  end

  -- Enable focus-events (required for FocusGained autocmd to work)
  vim.fn.system('tmux set-option -g focus-events on 2>/dev/null')

  -- Register global hooks to clear alerts when switching windows
  -- These fire on keyboard navigation (after-select-window) and mouse clicks (session-window-changed)
  -- The hook: clears alert flag and unsets window-specific format overrides (lets global theme take over)
  local clear_cmd = 'if-shell -F "#{@alert}" "set-window-option @alert 0 ; set-window-option -u window-status-format ; set-window-option -u window-status-current-format ; set-window-option -u @original_format ; set-window-option -u @original_current_format"'
  vim.fn.system(string.format("tmux set-hook -g after-select-window '%s' 2>/dev/null", clear_cmd))
  vim.fn.system(string.format("tmux set-hook -g session-window-changed '%s' 2>/dev/null", clear_cmd))
end

return M
