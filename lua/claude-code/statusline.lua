-- Claude Code status line integration
-- Reads real-time status from Claude CLI via bridge script
-- Uses hooks for accurate state detection

local M = {}

-- Timing constants
local POLL_INTERVAL_MS = 200     -- Poll files every 200ms
local DONE_DISPLAY_MS = 2000     -- Show "done" state for 2 seconds
local PERMISSION_TIMEOUT_MS = 60000  -- Recover from stuck "waiting" after 60s

-- Project-local state files (in <cwd>/.claude/)
-- Finds the most recently modified state file (supports multiple sessions)
local function get_state_file()
  local claude_dir = vim.fn.getcwd() .. '/.claude'
  local pattern = claude_dir .. '/state*.json'
  local files = vim.fn.glob(pattern, false, true)

  if #files == 0 then
    return claude_dir .. '/state.json'  -- Default fallback
  end

  -- Find most recently modified
  local newest_file = files[1]
  local newest_mtime = 0

  for _, file in ipairs(files) do
    local stat = vim.loop.fs_stat(file)
    if stat and stat.mtime.sec > newest_mtime then
      newest_mtime = stat.mtime.sec
      newest_file = file
    end
  end

  return newest_file
end

local function get_status_file()
  return vim.fn.getcwd() .. '/.claude/status.json'
end

-- Polling timer
local poll_timer = nil

-- Last modification times (to detect changes)
local last_status_mtime = 0
local last_state_mtime = 0

-- Cached data
local cached_status = nil  -- From STATUS_FILE (model, tokens, etc)
local cached_state = nil   -- From STATE_FILE (processing, done)
local done_timer = nil     -- Timer to clear "done" state
local permission_timer = nil  -- Timer to recover from stuck "waiting"

--- Nerdfont icons for display
M.icons = {
  idle = '󰚩',        -- nf-md-robot_outline
  processing = '󰦖',  -- nf-md-progress_clock
  waiting = '󰋗',     -- nf-md-help_circle (needs input)
  done = '󰄬',        -- nf-md-check
  error = '󰀦',       -- nf-md-alert
}

--- Colors (Catppuccin-inspired)
M.colors = {
  idle = '#6c7086',      -- Overlay0 (dimmed)
  processing = '#f9e2af', -- Yellow (working)
  waiting = '#fab387',   -- Peach (needs attention)
  done = '#a6e3a1',      -- Green (finished)
  error = '#f38ba8',     -- Red
}

--- Default configuration
M.config = {
  show_model = true,      -- "Opus", "Sonnet"
  show_tokens = true,     -- "12.5k tokens"
  show_cost = false,      -- "$0.0234" (off by default)
  show_lines = true,      -- "+50/-10"
  format = nil,           -- Custom format function(status) -> string
}

--- Format token count with k/M suffix
---@param n number Token count
---@return string Formatted string
local function format_tokens(n)
  if not n or n == 0 then
    return '0'
  elseif n >= 1000000 then
    return string.format('%.1fM', n / 1000000)
  elseif n >= 1000 then
    return string.format('%.1fk', n / 1000)
  else
    return tostring(n)
  end
end

--- Read Claude status from temp file
---@return table|nil Status data or nil if unavailable
function M.read_status()
  local f = io.open(get_status_file(), 'r')
  if not f then
    return nil
  end

  local content = f:read('*all')
  f:close()

  if not content or content == '' then
    return nil
  end

  local ok, data = pcall(vim.json.decode, content)
  if ok and data then
    cached_status = data
    return data
  end

  return nil
end

--- Get cached status (avoids file reads on every statusline refresh)
---@return table|nil
function M.get_cached_status()
  return cached_status
end

--- Read state from hook-written file
---@return table|nil State data
function M.read_state()
  local f = io.open(get_state_file(), 'r')
  if not f then
    return nil
  end

  local content = f:read('*all')
  f:close()

  if not content or content == '' then
    return nil
  end

  local ok, data = pcall(vim.json.decode, content)
  if ok and data then
    cached_state = data
    return data
  end

  return nil
end

--- Get state based on hook-written state file
---@return string 'idle', 'processing', 'waiting', 'done', or 'error'
function M.get_state()
  if not cached_state then
    return 'idle'
  end

  local state = cached_state.state
  if state == 'processing' or state == 'waiting' or state == 'done' then
    return state
  end

  return 'idle'
end

--- Get icon for current state
---@return string Nerdfont icon
function M.get_icon()
  local state = M.get_state()
  return M.icons[state] or M.icons.idle
end

--- Get color for current state
---@return string Hex color
function M.get_color()
  local state = M.get_state()
  return M.colors[state] or M.colors.idle
end

--- Build status string from Claude data
---@return string Status string for display
function M.get_status()
  local status = cached_status

  if not status then
    return ''
  end

  -- Use custom format function if provided
  if M.config.format then
    local ok, result = pcall(M.config.format, status)
    if ok then
      return result
    end
  end

  -- Build status parts
  local parts = {}
  local icon = M.get_icon()
  table.insert(parts, icon)

  -- Model name
  if M.config.show_model and status.model then
    table.insert(parts, status.model.display_name or 'Claude')
  end

  -- Token count
  if M.config.show_tokens and status.context_window then
    local tokens = status.context_window.total_input_tokens or 0
    table.insert(parts, format_tokens(tokens))
  end

  -- Lines changed
  if M.config.show_lines and status.cost then
    local added = status.cost.total_lines_added or 0
    local removed = status.cost.total_lines_removed or 0
    if added > 0 or removed > 0 then
      table.insert(parts, string.format('+%d/-%d', added, removed))
    end
  end

  -- Cost
  if M.config.show_cost and status.cost then
    local cost = status.cost.total_cost_usd or 0
    table.insert(parts, string.format('$%.4f', cost))
  end

  return table.concat(parts, ' | ')
end

--- Trigger lualine refresh if available
local function refresh_lualine()
  local ok, lualine = pcall(require, 'lualine')
  if ok and lualine.refresh then
    lualine.refresh()
  end
end

--- Callback when status file changes
local function on_status_update()
  M.read_status()
  refresh_lualine()
end

--- Callback when state file changes
local function on_state_update()
  M.read_state()
  refresh_lualine()

  -- Handle "done" state: clear after 2 seconds
  if cached_state and cached_state.state == 'done' then
    if done_timer then
      done_timer:stop()
    end
    done_timer = vim.defer_fn(function()
      cached_state = { state = 'idle' }
      refresh_lualine()
    end, DONE_DISPLAY_MS)
  end

  -- Handle "waiting" state: recover after 60 seconds (permission denial fallback)
  if cached_state and cached_state.state == 'waiting' then
    if permission_timer then
      permission_timer:stop()
    end
    permission_timer = vim.defer_fn(function()
      -- Only reset if still in waiting state
      if cached_state and cached_state.state == 'waiting' then
        cached_state = { state = 'idle' }
        refresh_lualine()
      end
    end, PERMISSION_TIMEOUT_MS)
  else
    -- Clear permission timer if not in waiting state
    if permission_timer then
      permission_timer:stop()
      permission_timer = nil
    end
  end
end

--- Get file modification time (0 if file doesn't exist)
---@param path string File path
---@return number Modification time in seconds
local function get_mtime(path)
  local stat = vim.loop.fs_stat(path)
  if stat then
    return stat.mtime.sec
  end
  return 0
end

-- Track which state file we're watching
local current_state_file = nil

--- Poll for file changes
local function poll_files()
  local status_mtime = get_mtime(get_status_file())
  local state_file = get_state_file()
  local state_mtime = get_mtime(state_file)

  -- Check if status file changed
  if status_mtime > last_status_mtime then
    last_status_mtime = status_mtime
    on_status_update()
  end

  -- Check if state file changed (or if we switched to a different session's file)
  if state_mtime > last_state_mtime or state_file ~= current_state_file then
    last_state_mtime = state_mtime
    current_state_file = state_file
    on_state_update()
  end
end

--- Start polling for status and state file changes
function M.start_watcher()
  -- Ensure local .claude directory exists
  vim.fn.mkdir(vim.fn.getcwd() .. '/.claude', 'p')

  -- Stop existing timer if any
  if poll_timer then
    poll_timer:stop()
    poll_timer:close()
  end

  -- Create polling timer
  poll_timer = vim.loop.new_timer()
  poll_timer:start(0, POLL_INTERVAL_MS, vim.schedule_wrap(poll_files))

  -- Initial reads
  M.read_status()
  M.read_state()
end

--- Stop polling
function M.stop_watcher()
  if poll_timer then
    poll_timer:stop()
    poll_timer:close()
    poll_timer = nil
  end

  -- Clean up all timers
  if done_timer then
    done_timer:stop()
    done_timer = nil
  end

  if permission_timer then
    permission_timer:stop()
    permission_timer = nil
  end
end

--- Setup statusline with config
---@param opts table|nil Configuration options
function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend('force', M.config, opts)
  end

  -- Start watching for status updates
  M.start_watcher()
end

--- Lualine component
---@return table Lualine component config
function M.lualine()
  return {
    M.get_status,
    color = function()
      return { fg = M.get_color() }
    end,
    cond = function()
      return cached_status ~= nil
    end,
    on_click = function()
      local ok, claude = pcall(require, 'claude-code')
      if ok and claude.picker then
        claude.picker()
      end
    end,
  }
end

return M
