-- claude-code.nvim buffer synchronization
-- Handles auto-save before sending and auto-refresh after Claude modifies files
-- Uses PostToolUse hook to trigger immediate buffer refresh

local M = {}

-- Timing constants
local POLL_INTERVAL_MS = 200  -- Poll file every 200ms

-- Project-local refresh file (finds most recent, supports multiple sessions)
local function get_refresh_file()
  local claude_dir = vim.fn.getcwd() .. '/.claude'
  local pattern = claude_dir .. '/refresh*'
  local files = vim.fn.glob(pattern, false, true)

  if #files == 0 then
    return claude_dir .. '/refresh'  -- Default fallback
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

-- Polling timer
local poll_timer = nil
local last_mtime = 0
local current_refresh_file = nil

--- Save all modified buffers to disk
--- Called before sending context to Claude so it reads the latest content
function M.save_modified_buffers()
  local saved_count = 0

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified and vim.bo[buf].buftype == '' then
      -- Get buffer name for file path check
      local bufname = vim.api.nvim_buf_get_name(buf)
      if bufname ~= '' then
        vim.api.nvim_buf_call(buf, function()
          vim.cmd('silent! write')
        end)
        saved_count = saved_count + 1
      end
    end
  end

  if saved_count > 0 then
    vim.notify(string.format('Auto-saved %d buffer(s)', saved_count), vim.log.levels.INFO)
  end
end

--- Force refresh all buffers (check for external changes)
---@param silent boolean|nil Suppress notification (default false)
function M.force_refresh(silent)
  vim.cmd('silent! checktime')
  if not silent then
    vim.notify('Buffers synced', vim.log.levels.INFO)
  end
end

--- Callback when refresh file changes (Claude wrote a file)
local function on_file_write()
  -- Immediate checktime when Claude writes files
  vim.cmd('silent! checktime')
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

--- Poll for refresh file changes
local function poll_refresh()
  local refresh_file = get_refresh_file()
  local mtime = get_mtime(refresh_file)

  -- Trigger if file changed or if we switched to a different session's file
  if mtime > last_mtime or refresh_file ~= current_refresh_file then
    last_mtime = mtime
    current_refresh_file = refresh_file
    if mtime > 0 then  -- Only trigger if file exists
      on_file_write()
    end
  end
end

--- Start polling the refresh file
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
  poll_timer:start(0, POLL_INTERVAL_MS, vim.schedule_wrap(poll_refresh))
end

--- Stop polling
function M.stop_watcher()
  if poll_timer then
    poll_timer:stop()
    poll_timer:close()
    poll_timer = nil
  end
end

--- Initialize sync module (call from setup)
function M.setup()
  M.start_watcher()
end

return M
