-- Claude Code session management
-- Manages multiple Claude CLI instances

local M = {}

-- Store for all Claude sessions
M.sessions = {}
M.current_session = nil
M.last_session = nil

---@class ClaudeSession
---@field name string Session name
---@field buf number Buffer number
---@field win number|nil Window number (if visible)
---@field job_id number Terminal job ID
---@field created_at number Creation timestamp
---@field last_used number Last access timestamp
---@field last_active number Last activity (output/input)
---@field state string 'idle'|'processing'|'waiting'|'error'
---@field is_visible boolean Currently shown

--- Create a new Claude session
---@param name string Session name
---@param opts table|nil Options
---@return ClaudeSession|nil
function M.create_session(name, opts)
  opts = opts or {}

  -- Check if session already exists
  if M.sessions[name] then
    vim.notify('Claude session "' .. name .. '" already exists', vim.log.levels.WARN)
    return M.sessions[name]
  end

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'claudecode'

  -- Save current buffer to restore later
  local current_buf = vim.api.nvim_get_current_buf()

  -- Temporarily switch to new buffer to start terminal
  vim.api.nvim_set_current_buf(buf)

  -- Start Claude CLI terminal
  local command = opts.command or 'claude'
  local job_id = vim.fn.termopen(command, {
    on_exit = function(_, exit_code, _)
      -- Schedule cleanup to avoid issues in callback context
      vim.schedule(function()
        if M.sessions[name] then
          local session = M.sessions[name]
          -- Delete buffer if it still exists (clears the named buffer)
          if session.buf and vim.api.nvim_buf_is_valid(session.buf) then
            vim.api.nvim_buf_delete(session.buf, { force = true })
          end
          M.sessions[name] = nil
          if M.current_session == name then
            M.current_session = nil
          end
          if M.last_session == name then
            M.last_session = nil
          end
        end
      end)
    end,
  })

  -- Restore original buffer
  vim.api.nvim_set_current_buf(current_buf)

  if job_id == 0 or job_id == -1 then
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.notify('Failed to create Claude session', vim.log.levels.ERROR)
    return nil
  end

  -- Clean up any stale buffer with this name (from previous session that didn't fully clean up)
  local buffer_name = 'claude-code://' .. name
  local existing_buf = vim.fn.bufnr(buffer_name)
  if existing_buf ~= -1 and existing_buf ~= buf then
    pcall(vim.api.nvim_buf_delete, existing_buf, { force = true })
  end

  -- Set buffer name and variables for identification
  vim.api.nvim_buf_set_name(buf, buffer_name)
  vim.b[buf].claude_code = true
  vim.b[buf].claude_session = name

  -- Set up buffer-local keymaps
  M.setup_keymaps(buf, name)

  -- Create session object
  local session = {
    name = name,
    buf = buf,
    win = nil,
    job_id = job_id,
    created_at = os.time(),
    last_used = os.time(),
    last_active = os.time(),
    state = 'idle',
    is_visible = false,
  }

  M.sessions[name] = session

  return session
end

--- Set up buffer-local keymaps for Claude terminal
---@param buf number
---@param name string
function M.setup_keymaps(buf, name)
  -- Esc in terminal mode: Pass to Claude (don't intercept!)
  -- Claude needs Esc for its own UI
  -- To exit terminal mode, use Ctrl-\ Ctrl-n (standard Neovim)

  -- In normal mode: q to close (standard preview/terminal pattern)
  vim.keymap.set('n', 'q', function()
    require('claude-code.window').hide_window()
  end, { buffer = buf, desc = 'Hide Claude window' })

  -- Alternative: Ctrl-c to close (also standard)
  vim.keymap.set('n', '<C-c>', function()
    require('claude-code.window').hide_window()
  end, { buffer = buf, desc = 'Hide Claude window' })

  -- Exit terminal mode with standard Neovim key
  vim.keymap.set('t', '<C-\\><C-n>', '<C-\\><C-n>', { buffer = buf, desc = 'Exit terminal mode' })

  -- Quick toggle picker
  vim.keymap.set('t', '<C-\\><C-p>', function()
    vim.cmd('stopinsert')
    require('claude-code').picker()
  end, { buffer = buf, desc = 'Claude session picker' })

  vim.keymap.set('n', '<C-\\><C-p>', function()
    require('claude-code').picker()
  end, { buffer = buf, desc = 'Claude session picker' })

  -- Quick toggle with Ctrl-c from terminal mode
  vim.keymap.set('t', '<C-c>', function()
    require('claude-code.window').hide_window()
  end, { buffer = buf, desc = 'Hide Claude window' })
end

--- Get or create session (auto-create if missing)
---@param name string
---@param opts table|nil
---@return ClaudeSession
function M.get_or_create(name, opts)
  if M.sessions[name] then
    return M.sessions[name]
  end
  return M.create_session(name, opts)
end

--- Delete a Claude session
---@param name string
function M.delete_session(name)
  local session = M.sessions[name]
  if not session then
    return
  end

  -- Close window if open
  if session.win and vim.api.nvim_win_is_valid(session.win) then
    vim.api.nvim_win_close(session.win, true)
  end

  -- Stop terminal job
  if session.job_id then
    vim.fn.jobstop(session.job_id)
  end

  -- Delete buffer
  if session.buf and vim.api.nvim_buf_is_valid(session.buf) then
    vim.api.nvim_buf_delete(session.buf, { force = true })
  end

  M.sessions[name] = nil

  if M.current_session == name then
    M.current_session = nil
  end
  if M.last_session == name then
    M.last_session = nil
  end
end

--- Get session by name
---@param name string
---@return ClaudeSession|nil
function M.get_session(name)
  return M.sessions[name]
end

--- List all sessions (sorted by last_used)
---@return string[]
function M.list_sessions()
  local names = {}
  for name, _ in pairs(M.sessions) do
    table.insert(names, name)
  end

  -- Sort by last used (most recent first)
  table.sort(names, function(a, b)
    return M.sessions[a].last_used > M.sessions[b].last_used
  end)

  return names
end

--- Update session state
---@param name string
---@param state string
function M.update_state(name, state)
  local session = M.sessions[name]
  if not session then
    return
  end

  -- Skip if state hasn't changed
  if session.state == state then
    return
  end

  session.state = state
  session.last_active = os.time()

  -- Update window title if visible
  require('claude-code.window').update_title(name, state)
end

--- Send text to a session
---@param name string
---@param text string
---@param submit boolean|nil Auto-submit (default true)
function M.send_to_session(name, text, submit)
  local session = M.sessions[name]
  if not session or not session.job_id then
    vim.notify('Claude session "' .. name .. '" not found', vim.log.levels.ERROR)
    return
  end

  vim.fn.chansend(session.job_id, text)
  if submit ~= false then
    vim.fn.chansend(session.job_id, '\n')
    -- Mark as processing when user submits
    require('claude-code.state').on_send(name)
  end

  session.last_active = os.time()
end

return M
