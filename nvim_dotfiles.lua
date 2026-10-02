-- Mirrors ~/.vimrc. Installed to ~/.config/nvim/plugin/, which loads after kickstart's init.lua.
vim.o.relativenumber = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.o.scrolloff = 5

vim.keymap.set('n', 'gn', '<cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', 'gp', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', 'gd', '<cmd>bprevious | bdelete #<CR>', { desc = 'Delete buffer, keep window' })
-- Omarchy's LazyVim has no Telescope
if pcall(require, 'telescope.builtin') then
  vim.keymap.set('n', 'gh', function() require('telescope.builtin').find_files() end, { desc = 'Find files' })
end
