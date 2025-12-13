-- claude-code.nvim plugin loader
-- This file is automatically loaded by Neovim

if vim.g.loaded_claude_code then
  return
end
vim.g.loaded_claude_code = true

-- Plugin requires Neovim 0.8+
if vim.fn.has('nvim-0.8') == 0 then
  vim.api.nvim_err_writeln('claude-code.nvim requires Neovim 0.8 or higher')
  return
end
