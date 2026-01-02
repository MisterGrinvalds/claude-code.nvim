-- Claude Code state detection
-- Monitors Claude CLI output to detect session states

local M = {}

-- Timer for periodic idle checks
M.idle_timer = nil

-- Code block tracking per session
M.code_block_counts = {}

--- Start monitoring a Claude session
---@param name string Session name
function M.monitor_session(name)
  local session_module = require('claude-code.session')
  local session = session_module.get_session(name)

  if not session or not session.buf then
    return
  end

  -- Attach to buffer to monitor output
  vim.api.nvim_buf_attach(session.buf, false, {
    on_lines = function(_, bufnr, _, firstline, lastline, new_lastline)
      -- Get newly added lines
      local new_lines = vim.api.nvim_buf_get_lines(bufnr, firstline, new_lastline, false)

      -- Track code blocks
      local prev_count = M.code_block_counts[name] or 0
      local current_count = 0

      for _, line in ipairs(new_lines) do
        -- Count code blocks
        if line:match('^```') then
          current_count = current_count + 1
        end

        -- Detect state from output patterns
        if line:match('^%s*>') or line:match('Enter your prompt') then
          -- Prompt detected - waiting for user input
          M.update_session_state(name, 'waiting')

          -- Check if new code blocks were added since last check
          local block_count = math.floor(current_count / 2) -- Pairs of ``` marks
          if block_count > prev_count and block_count > 0 then
            vim.schedule(function()
              vim.notify(
                string.format('Claude provided %d code block(s). Press <leader>cr to apply', block_count),
                vim.log.levels.INFO
              )
            end)
            M.code_block_counts[name] = block_count
          end
        elseif line:match('^%s*<') or line:match('Assistant:') or #line > 0 then
          -- Response output - processing
          if session.state ~= 'processing' then
            M.update_session_state(name, 'processing')
          end
        end

        -- Check for errors
        if line:match('[Ee]rror') or line:match('[Ff]ailed') then
          M.update_session_state(name, 'error')
        end
      end

      -- Update last activity
      session.last_active = os.time()
    end,
  })

  -- Start idle detection timer if not already running
  M.start_idle_timer()
end

--- Update session state and trigger UI updates
---@param name string Session name
---@param new_state string New state
function M.update_session_state(name, new_state)
  local session_module = require('claude-code.session')
  session_module.update_state(name, new_state)
end

--- Start periodic idle detection
function M.start_idle_timer()
  if M.idle_timer then
    return -- Already running
  end

  M.idle_timer = vim.loop.new_timer()
  M.idle_timer:start(
    0, -- Start immediately
    1000, -- Check every second
    vim.schedule_wrap(function()
      local session_module = require('claude-code.session')

      for name, session in pairs(session_module.sessions) do
        -- If no activity for 5 seconds and not already idle
        if os.time() - session.last_active > 5 and session.state ~= 'idle' then
          M.update_session_state(name, 'idle')
        end
      end
    end)
  )
end

--- Stop idle detection timer
function M.stop_idle_timer()
  if M.idle_timer then
    M.idle_timer:stop()
    M.idle_timer:close()
    M.idle_timer = nil
  end
end

return M
