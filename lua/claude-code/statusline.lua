-- Claude Code status line integration
-- Provides status indicators for lualine

local M = {}

--- State icons
local state_icons = {
  idle = '●',       -- Green dot
  processing = '⧗', -- Yellow hourglass
  waiting = '◐',    -- Blue half-circle
  error = '⚠',      -- Red warning
}

--- Get status string for all Claude sessions
---@return string Status string for status line
function M.get_status_string()
  local session_module = require('claude-code.session')
  local sessions = session_module.sessions

  if vim.tbl_isempty(sessions) then
    return ''
  end

  local parts = {}
  for name, session in pairs(sessions) do
    local icon = state_icons[session.state] or '○'
    table.insert(parts, string.format('%s:%s', name, icon))
  end

  return ' ' .. table.concat(parts, ' ')
end

--- Get primary state (for color coding)
---@return string State of current or most recent session
function M.get_primary_state()
  local session_module = require('claude-code.session')

  -- Use current session if set
  if session_module.current_session then
    local session = session_module.get_session(session_module.current_session)
    if session then
      return session.state
    end
  end

  -- Use last session
  if session_module.last_session then
    local session = session_module.get_session(session_module.last_session)
    if session then
      return session.state
    end
  end

  -- Default
  return 'idle'
end

--- Get lualine component configuration
---@return table Lualine component config
function M.get_lualine_component()
  return {
    function()
      return M.get_status_string()
    end,

    -- Dynamic color based on state
    color = function()
      local state = M.get_primary_state()

      if state == 'processing' then
        return { fg = '#f9e2af' } -- Yellow (Catppuccin)
      elseif state == 'waiting' then
        return { fg = '#89b4fa' } -- Blue
      elseif state == 'error' then
        return { fg = '#f38ba8' } -- Red
      else
        return { fg = '#a6e3a1' } -- Green
      end
    end,

    -- Icon
    icon = '',

    -- Click handler - show picker
    on_click = function()
      require('claude-code').picker()
    end,

    -- Only show if sessions exist
    cond = function()
      local session_module = require('claude-code.session')
      return not vim.tbl_isempty(session_module.sessions)
    end,
  }
end

return M
