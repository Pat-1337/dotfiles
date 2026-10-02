-- Mirrors ~/.vimrc. Installed to ~/.config/nvim/plugin/, which loads after kickstart's init.lua.
vim.o.relativenumber = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.o.scrolloff = 5

vim.keymap.set('n', 'gn', '<cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', 'gp', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', 'gd', function()
  if vim.fn.tabpagenr '$' > 1 and vim.fn.winnr '$' == 1 then
    vim.cmd.bdelete()
  else
    vim.cmd 'bprevious | bdelete #'
  end
end, { desc = 'Delete buffer; closes a single-window tab' })
-- Omarchy's LazyVim has no Telescope
if pcall(require, 'telescope.builtin') then
  vim.keymap.set('n', 'gh', function() require('telescope.builtin').find_files() end, { desc = 'Find files' })
end
vim.keymap.set('n', '<leader>tn', '<cmd>tabnew<CR>', { desc = '[T]ab [N]ew' })

-- Stops netrw clashing with the <C-h>/<C-l> window maps (E225)
vim.keymap.set('n', '<Plug>(dotfiles-netrw-hide)', '<Plug>NetrwHideEdit')
vim.keymap.set('n', '<Plug>(dotfiles-netrw-refresh)', '<Plug>NetrwRefresh')

-- Omarchy's LazyVim themes nvim itself
if vim.pack and not package.loaded.lazy then
  vim.pack.add { 'https://github.com/rebelot/kanagawa.nvim', 'https://github.com/EdenEast/nightfox.nvim' }

  local themes = { dark = 'kanagawa-wave', light = 'dayfox' }
  local current
  local function apply(mode)
    if mode == current then return end
    current = mode
    vim.o.background = mode
    vim.cmd.colorscheme(themes[mode])
  end

  if vim.fn.has 'mac' == 1 and not vim.env.SSH_CONNECTION then
    local style = vim.system({ 'defaults', 'read', '-g', 'AppleInterfaceStyle' }):wait().stdout
    apply(style:match 'Dark' and 'dark' or 'light')
    vim.pack.add { 'https://github.com/f-person/auto-dark-mode.nvim' }
    require('auto-dark-mode').setup {
      set_dark_mode = function() apply 'dark' end,
      set_light_mode = function() apply 'light' end,
    }
  else
    -- No desktop appearance to follow, so light from 07:00 to 19:00
    local function by_clock()
      local hour = tonumber(os.date '%H')
      apply((hour >= 7 and hour < 19) and 'light' or 'dark')
    end
    by_clock()
    vim.uv.new_timer():start(60000, 60000, vim.schedule_wrap(by_clock))
  end
end
