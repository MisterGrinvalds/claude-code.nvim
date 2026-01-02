-- Claude Code state management
-- Simple action-based state tracking (not output parsing)

local M = {}
local sync = require('claude-code.sync')

--- Set session to processing state (called when user sends text)
---@param name string Session name
function M.set_processing(name)
  local session_module = require('claude-code.session')
  local session = session_module.get_session(name)

  if not session then
    return
  end

  local old_state = session.state
  session_module.update_state(name, 'processing')

  -- Start watching for file changes
  if old_state ~= 'processing' then
    sync.start_watching()
  end
end

--- Set session to waiting state (ready for input)
---@param name string Session name
function M.set_waiting(name)
  local session_module = require('claude-code.session')
  local session = session_module.get_session(name)

  if not session then
    return
  end

  local old_state = session.state
  session_module.update_state(name, 'waiting')

  -- If coming from processing, refresh and show done
  if old_state == 'processing' then
    sync.stop_watching()
    sync.refresh_buffers()
    require('claude-code.statusline').mark_done()
  end
end

--- Set session to idle state
---@param name string Session name
function M.set_idle(name)
  local session_module = require('claude-code.session')
  session_module.update_state(name, 'idle')
end

--- Called when Claude window is shown
---@param name string Session name
function M.on_show(name)
  local session_module = require('claude-code.session')
  local session = session_module.get_session(name)

  if session and session.state == 'idle' then
    session_module.update_state(name, 'waiting')
  end
end

--- Called when Claude window is hidden
---@param name string Session name
function M.on_hide(name)
  -- Always refresh buffers when hiding Claude window
  -- This is the most reliable time to catch file changes
  sync.force_refresh(true) -- silent

  local session_module = require('claude-code.session')
  local session = session_module.get_session(name)

  if session and session.state == 'processing' then
    -- If still processing when hidden, mark done
    require('claude-code.statusline').mark_done()
    session_module.update_state(name, 'idle')
  end
end

--- Called when user sends text to Claude
---@param name string Session name
function M.on_send(name)
  M.set_processing(name)
end

return M
