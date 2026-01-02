-- claude-code.nvim buffer synchronization
-- Handles auto-save before sending and auto-refresh after Claude modifies files
-- Uses PostToolUse hook to trigger immediate buffer refresh

local M = {}

-- Get project-specific refresh file (supports multiple instances)
local function get_refresh_file()
  return vim.fn.getcwd() .. '/.claude-refresh'
end

-- File watcher
local refresh_watcher = nil

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

--- Ensure file exists, create if not
---@param path string File path
local function ensure_file(path)
  local f = io.open(path, 'r')
  if f then
    f:close()
  else
    f = io.open(path, 'w')
    if f then
      f:write('')
      f:close()
    end
  end
end

--- Start watching the refresh file
function M.start_watcher()
  if refresh_watcher then
    return -- Already watching
  end

  local refresh_file = get_refresh_file()
  ensure_file(refresh_file)

  refresh_watcher = vim.loop.new_fs_event()
  local ok = refresh_watcher:start(refresh_file, {}, vim.schedule_wrap(function(err, filename, events)
    if not err then
      on_file_write()
    end
  end))

  if not ok then
    refresh_watcher:close()
    refresh_watcher = nil
  end
end

--- Stop watching the refresh file
function M.stop_watcher()
  if refresh_watcher then
    refresh_watcher:stop()
    refresh_watcher:close()
    refresh_watcher = nil
  end
end

--- Initialize sync module (call from setup)
function M.setup()
  M.start_watcher()
end

return M
