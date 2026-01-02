-- Telescope picker for Claude Code sessions
local M = {}

--- Format time ago (e.g., "2m ago", "1h ago")
---@param timestamp number
---@return string
local function time_ago(timestamp)
  local diff = os.time() - timestamp
  if diff < 60 then
    return diff .. 's ago'
  elseif diff < 3600 then
    return math.floor(diff / 60) .. 'm ago'
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. 'h ago'
  else
    return math.floor(diff / 86400) .. 'd ago'
  end
end

--- Show Claude session picker
function M.show()
  local session_module = require('claude-code.session')
  local sessions = {}

  -- Convert sessions dict to array
  for name, session in pairs(session_module.sessions) do
    table.insert(sessions, session)
  end

  -- Sort by last_used
  table.sort(sessions, function(a, b)
    return a.last_used > b.last_used
  end)

  if #sessions == 0 then
    vim.notify('No Claude sessions. Creating "main" session...', vim.log.levels.INFO)
    require('claude-code').toggle()
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local entry_display = require('telescope.pickers.entry_display')

  local displayer = entry_display.create({
    separator = ' ',
    items = {
      { width = 25 }, -- Session name
      { width = 12 }, -- State
      { width = 20 }, -- Last activity
      { remaining }, -- Context/description
    },
  })

  local make_display = function(entry)
    local state_display = entry.state
    local last_activity = time_ago(entry.last_active)
    local description = 'Claude session'

    return displayer({
      { entry.name, 'TelescopeResultsIdentifier' },
      { state_display, entry.state == 'processing' and 'TelescopeResultsSpecialComment' or 'TelescopeResultsComment' },
      { last_activity, 'TelescopeResultsLineNr' },
      { description, 'TelescopeResultsComment' },
    })
  end

  pickers
    .new({
      prompt_title = '󰧑 Claude Code Sessions',
      finder = finders.new_table({
        results = sessions,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.name,
            name = entry.name,
            state = entry.state,
            last_active = entry.last_active,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Default: switch to session
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          if selection then
            require('claude-code.window').show_session(selection.value.name)
          end
        end)

        -- Ctrl-x: delete session
        map('i', '<c-x>', function()
          local selection = action_state.get_selected_entry()
          if selection and #sessions > 1 then
            actions.close(prompt_bufnr)
            session_module.delete_session(selection.value.name)
          else
            vim.notify("Can't delete last Claude session", vim.log.levels.WARN)
          end
        end)

        -- Ctrl-n: new session
        map('i', '<c-n>', function()
          actions.close(prompt_bufnr)
          vim.ui.input({ prompt = 'Session name: ' }, function(name)
            if name and name ~= '' then
              session_module.create_session(name)
              require('claude-code.window').show_session(name)
            end
          end)
        end)

        -- Ctrl-r: rename session
        map('i', '<c-r>', function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          if selection then
            local old_name = selection.value.name
            vim.ui.input({ prompt = 'New name: ', default = old_name }, function(new_name)
              if new_name and new_name ~= '' and new_name ~= old_name then
                -- Rename session
                local session = session_module.sessions[old_name]
                if session then
                  session_module.sessions[new_name] = session
                  session.name = new_name
                  session_module.sessions[old_name] = nil

                  -- Update references
                  if session_module.current_session == old_name then
                    session_module.current_session = new_name
                  end
                  if session_module.last_session == old_name then
                    session_module.last_session = new_name
                  end

                  -- Update buffer name
                  vim.api.nvim_buf_set_name(session.buf, 'claude-code://' .. new_name)

                  vim.notify('Renamed to: ' .. new_name, vim.log.levels.INFO)
                end
              end
            end)
          end
        end)

        return true
      end,
    })
    :find()
end

return M
