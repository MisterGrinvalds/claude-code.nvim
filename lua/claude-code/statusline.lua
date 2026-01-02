-- Claude Code status line integration
-- Reads real-time status from Claude CLI via bridge script
-- Uses hooks for accurate state detection

local M = {}

-- Status file written by bridge script (model, tokens, lines)
local STATUS_FILE = '/tmp/claude-code-status.json'

-- State file written by hooks (processing, done)
local STATE_FILE = '/tmp/claude-state.json'

-- File watchers
local status_watcher = nil
local state_watcher = nil

-- Cached data
local cached_status = nil  -- From STATUS_FILE (model, tokens, etc)
local cached_state = nil   -- From STATE_FILE (processing, done)
local done_timer = nil     -- Timer to clear "done" state

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
  local f = io.open(STATUS_FILE, 'r')
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
    last_update = os.time()
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
  local f = io.open(STATE_FILE, 'r')
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

--- Callback when status file changes
local function on_status_update()
  M.read_status()
end

--- Callback when state file changes
local function on_state_update()
  M.read_state()

  -- If state is "done", clear it after 3 seconds
  if cached_state and cached_state.state == 'done' then
    if done_timer then
      done_timer:stop()
    end
    done_timer = vim.defer_fn(function()
      cached_state = { state = 'idle' }
    end, 3000)
  end
end

--- Ensure file exists, create if not
---@param path string File path
local function ensure_file(path)
  local f = io.open(path, 'r')
  if f then
    f:close()
  else
    f = io.open(path, 'w')
    if f then
      f:write('{}')
      f:close()
    end
  end
end

--- Start a file watcher
---@param path string File path to watch
---@param callback function Callback on change
---@return userdata|nil Watcher handle
local function start_file_watcher(path, callback)
  ensure_file(path)

  local w = vim.loop.new_fs_event()
  local ok = w:start(path, {}, vim.schedule_wrap(function(err, filename, events)
    if not err then
      callback()
    end
  end))

  if not ok then
    w:close()
    return nil
  end

  return w
end

--- Start watching status and state files
function M.start_watcher()
  if not status_watcher then
    status_watcher = start_file_watcher(STATUS_FILE, on_status_update)
  end

  if not state_watcher then
    state_watcher = start_file_watcher(STATE_FILE, on_state_update)
  end

  -- Initial reads
  M.read_status()
  M.read_state()
end

--- Stop watching files
function M.stop_watcher()
  if status_watcher then
    status_watcher:stop()
    status_watcher:close()
    status_watcher = nil
  end

  if state_watcher then
    state_watcher:stop()
    state_watcher:close()
    state_watcher = nil
  end

  if done_timer then
    done_timer:stop()
    done_timer = nil
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
