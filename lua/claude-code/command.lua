-- Claude Code command dispatcher
-- Provides unified :Claude <subcommand> API similar to Telescope

local M = {}

-- Subcommand registry
-- Each entry: { fn = function, desc = string, complete = function|nil }
M.subcommands = {}

--- Register a subcommand
---@param name string Subcommand name
---@param fn function Function to execute
---@param desc string Description
---@param complete function|nil Optional completion function
function M.register(name, fn, desc, complete)
  M.subcommands[name] = {
    fn = fn,
    desc = desc,
    complete = complete,
  }
end

--- Get sorted list of subcommand names
---@return string[]
function M.list()
  local names = vim.tbl_keys(M.subcommands)
  table.sort(names)
  return names
end

--- Run a subcommand
---@param cmd string|nil Subcommand name (nil = default action)
---@param args string[] Additional arguments
function M.run(cmd, args)
  local claude = require('claude-code')

  -- Default action: toggle
  if not cmd or cmd == '' then
    claude.toggle()
    return
  end

  local subcmd = M.subcommands[cmd]
  if not subcmd then
    vim.notify('Unknown Claude command: ' .. cmd, vim.log.levels.ERROR)
    vim.notify('Available: ' .. table.concat(M.list(), ', '), vim.log.levels.INFO)
    return
  end

  subcmd.fn(args)
end

--- Completion function for :Claude command
---@param arg_lead string Current argument being typed
---@param cmd_line string Full command line
---@param cursor_pos number Cursor position
---@return string[]
function M.complete(arg_lead, cmd_line, cursor_pos)
  local parts = vim.split(cmd_line:sub(1, cursor_pos), '%s+', { trimempty = true })
  local n = #parts

  -- Account for trailing space (user wants next completion)
  if cmd_line:sub(cursor_pos, cursor_pos) == ' ' then
    n = n + 1
  end

  -- Level 1: Complete subcommand names
  if n <= 2 then
    local commands = M.list()
    if arg_lead == '' then
      return commands
    end
    return vim.tbl_filter(function(cmd)
      return vim.startswith(cmd, arg_lead)
    end, commands)
  end

  -- Level 2+: Subcommand-specific completion
  local subcmd_name = parts[2]
  local subcmd = M.subcommands[subcmd_name]

  if subcmd and subcmd.complete then
    return subcmd.complete(arg_lead, parts)
  end

  return {}
end

--- Initialize default subcommands
function M.setup()
  local claude = require('claude-code')

  -- Session completion helper
  local function complete_sessions(arg_lead)
    local sessions = claude.session.list_sessions()
    if arg_lead == '' then
      return sessions
    end
    return vim.tbl_filter(function(name)
      return vim.startswith(name, arg_lead)
    end, sessions)
  end

  -- Register all subcommands
  M.register('toggle', function()
    claude.toggle()
  end, 'Toggle Claude window')

  M.register('new', function(args)
    claude.new_session(args[1])
  end, 'Create new session', function(arg_lead)
    return complete_sessions(arg_lead)
  end)

  M.register('delete', function(args)
    claude.delete_session(args[1])
  end, 'Delete session', function(arg_lead)
    return complete_sessions(arg_lead)
  end)

  M.register('picker', function()
    claude.picker()
  end, 'Open session picker')

  M.register('install', function(args)
    local force = args[1] == '--force' or args[1] == '-f'
    claude.install_hooks(force)
  end, 'Install Claude Code hooks', function()
    return { '--force' }
  end)

  M.register('file', function()
    claude.send_file()
  end, 'Send current file to Claude')

  M.register('selection', function()
    claude.send_selection()
  end, 'Send selection to Claude')

  M.register('diagnostics', function()
    claude.send_diagnostics()
  end, 'Send diagnostics to Claude')

  M.register('ask', function()
    claude.ask()
  end, 'Ask Claude a question')

  M.register('replace', function()
    claude.pick_and_replace()
  end, 'Replace with Claude code block')

  M.register('status', function()
    local status = claude.get_status()
    if vim.tbl_isempty(status) then
      vim.notify('No active Claude sessions', vim.log.levels.INFO)
    else
      print(vim.inspect(status))
    end
  end, 'Show session status')
end

return M
