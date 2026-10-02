-- Mirrors ~/.vimrc, except that the LSP keys follow Zed.
-- Installed to ~/.config/nvim/plugin/, which loads after kickstart's init.lua.
vim.o.relativenumber = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.o.scrolloff = 5

vim.keymap.set('n', 'gn', '<cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', 'gp', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<leader>bd', function()
  local editors = vim.tbl_filter(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype ~= 'neo-tree' end, vim.api.nvim_tabpage_list_wins(0))
  if vim.fn.tabpagenr '$' > 1 and #editors == 1 then
    vim.cmd.bdelete()
  else
    vim.cmd 'bprevious | bdelete #'
  end
end, { desc = '[B]uffer [D]elete; closes a single-window tab' })
-- Omarchy's LazyVim has no Telescope
if pcall(require, 'telescope.builtin') then
  vim.keymap.set('n', 'gh', function() require('telescope.builtin').find_files() end, { desc = 'Find files' })
  -- netrw's gh hides dot-files, so that moves to g. and gh searches the browsed folder
  vim.cmd [[
    function! DotfilesNetrwFind(islocal) abort
      lua require('telescope.builtin').find_files { cwd = vim.b.netrw_curdir }
      return ''
    endfunction
    function! DotfilesNetrwDotfiles(islocal) abort
      call netrw#Call('NetrwHidden', a:islocal)
      return ''
    endfunction
  ]]
  vim.g.Netrw_UserMaps = { { 'gh', 'DotfilesNetrwFind' }, { 'g.', 'DotfilesNetrwDotfiles' } }
end
vim.keymap.set('n', '<leader>tn', '<cmd>tabnew<CR>', { desc = '[T]ab [N]ew' })

local function tab_files()
  local bufs = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].buftype == '' then bufs[b] = true end
  end
  return vim.tbl_keys(bufs)
end
vim.keymap.set('n', '<leader>tw', function()
  for _, b in ipairs(tab_files()) do
    if vim.bo[b].modified and vim.api.nvim_buf_get_name(b) ~= '' then vim.api.nvim_buf_call(b, function() vim.cmd.write() end) end
  end
end, { desc = '[T]ab [W]rite: save the files in this tab' })
vim.keymap.set('n', '<leader>tq', function()
  for _, b in ipairs(tab_files()) do
    if vim.bo[b].modified then
      if vim.api.nvim_buf_get_name(b) == '' then vim.bo[b].modified = false else vim.api.nvim_buf_call(b, function() vim.cmd 'edit!' end) end
    end
  end
  -- The last tab quits, still asking about unsaved files open elsewhere
  vim.cmd(vim.fn.tabpagenr '$' > 1 and 'tabclose' or 'confirm qall')
end, { desc = '[T]ab [Q]uit: close this tab, discarding its changes' })

-- Stops netrw clashing with the <C-h>/<C-l> window maps (E225)
vim.keymap.set('n', '<Plug>(dotfiles-netrw-hide)', '<Plug>NetrwHideEdit')
vim.keymap.set('n', '<Plug>(dotfiles-netrw-refresh)', '<Plug>NetrwRefresh')

-- Zed's vim-mode LSP keys
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('dotfiles-lsp-keys', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    -- ty answers hover; ruff's would only repeat lint codes
    if client and client.name == 'ruff' then client.server_capabilities.hoverProvider = false end
    local has_tb, tb = pcall(require, 'telescope.builtin')
    local function map(lhs, fn, desc) vim.keymap.set('n', lhs, fn, { buffer = ev.buf, desc = desc }) end
    map('gd', has_tb and tb.lsp_definitions or vim.lsp.buf.definition, 'Go to definition')
    map('gD', vim.lsp.buf.declaration, 'Go to declaration')
    map('gy', has_tb and tb.lsp_type_definitions or vim.lsp.buf.type_definition, 'Go to type definition')
    map('gI', has_tb and tb.lsp_implementations or vim.lsp.buf.implementation, 'Go to implementation')
    map('gA', has_tb and tb.lsp_references or vim.lsp.buf.references, 'Find all references')
    map('g.', vim.lsp.buf.code_action, 'Code actions')
    map('gs', has_tb and tb.lsp_document_symbols or vim.lsp.buf.document_symbol, 'File symbols')
    map('gS', has_tb and tb.lsp_dynamic_workspace_symbols or vim.lsp.buf.workspace_symbol, 'Project symbols')
    map('cd', vim.lsp.buf.rename, 'Rename')
    map('g]', function() vim.diagnostic.jump { count = 1, float = true } end, 'Next diagnostic')
    map('g[', function() vim.diagnostic.jump { count = -1, float = true } end, 'Previous diagnostic')
  end,
})
-- Homebrew's rust shadows rustup on PATH and lacks rust-src, so rust-analyzer gets rustup's
vim.lsp.config('rust_analyzer', { cmd_env = { PATH = vim.fs.normalize '~/.cargo/bin' .. ':' .. vim.env.PATH } })
for server, cmd in pairs { ty = 'ty', ruff = 'ruff', rust_analyzer = 'rust-analyzer', bashls = 'bash-language-server' } do
  if vim.fn.executable(cmd) == 1 then vim.lsp.enable(server) end
end
-- Shell: bash-language-server, which runs shellcheck for warnings and shfmt to format, all from kickstart's Mason
local has_mason, registry = pcall(require, 'mason-registry')
if has_mason then
  registry.refresh(function()
    for _, name in ipairs { 'bash-language-server', 'shellcheck', 'shfmt' } do
      if registry.has_package(name) and not registry.is_installed(name) then
        registry.get_package(name):install({}, function(ok)
          if ok and name == 'bash-language-server' then vim.schedule(function() vim.lsp.enable 'bashls' end) end
        end)
      end
    end
  end)
end

-- Omarchy's LazyVim brings its own theme and file tree
if vim.pack and not package.loaded.lazy then
  -- Icons need a Nerd Font, which setup.sh installs. Kickstart checks this flag before
  -- this file runs, so its icon setup is repeated here.
  vim.g.have_nerd_font = true
  if pcall(require, 'mini.icons') then
    require('mini.icons').setup()
    MiniIcons.mock_nvim_web_devicons()
    if MiniStatusline then MiniStatusline.config.use_icons = true end
  end

  vim.pack.add { 'https://github.com/rebelot/kanagawa.nvim', 'https://github.com/EdenEast/nightfox.nvim' }

  -- File tree on the left, as NERDTree in ~/.vimrc; Tab hops in and out, as in Zed
  vim.pack.add {
    { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
    'https://github.com/nvim-lua/plenary.nvim',
    'https://github.com/MunifTanjim/nui.nvim',
  }
  local function back() vim.cmd.wincmd 'p' end
  local function copy_path(modifier)
    return function(state)
      local path = vim.fn.fnamemodify(state.tree:get_node().path, modifier)
      vim.fn.setreg('+', path)
      vim.notify('Copied ' .. path)
    end
  end
  require('neo-tree').setup {
    close_if_last_window = true,
    window = {
      position = 'left',
      -- Your Zed project panel keys
      mappings = {
        ['<Tab>'] = back,
        ['<S-CR>'] = 'open_tabnew',
        h = 'close_node',
        l = 'open',
        o = 'open',
        zc = 'close_node',
        zo = 'open',
        c = 'copy_to_clipboard',
        Y = copy_path ':.',
        gy = copy_path ':p',
      },
    },
    filesystem = {
      follow_current_file = { enabled = true },
      hijack_netrw_behavior = 'open_default',
    },
  }
  vim.keymap.set('n', '<Tab>', '<cmd>Neotree reveal<CR>', { desc = 'Reveal file in tree' })
  -- Each tab has its own windows, so a new tab gets its own copy of the tree
  vim.api.nvim_create_autocmd('TabNewEntered', {
    group = vim.api.nvim_create_augroup('dotfiles-tree-tabs', { clear = true }),
    callback = function() vim.schedule(function() vim.cmd 'Neotree show' end) end,
  })
  -- :q in the tree beside only an empty startup window quits nvim
  vim.api.nvim_create_autocmd('QuitPre', {
    group = vim.api.nvim_create_augroup('dotfiles-tree-quit', { clear = true }),
    callback = function()
      if vim.bo.filetype ~= 'neo-tree' then return end
      local others = vim.tbl_filter(function(w) return w ~= vim.api.nvim_get_current_win() end, vim.api.nvim_tabpage_list_wins(0))
      for _, w in ipairs(others) do
        local b = vim.api.nvim_win_get_buf(w)
        local empty = vim.api.nvim_buf_get_name(b) == '' and not vim.bo[b].modified and vim.api.nvim_buf_line_count(b) == 1
          and vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] == ''
        if not empty then return end
      end
      for _, w in ipairs(others) do vim.api.nvim_win_close(w, true) end
    end,
  })
  vim.api.nvim_create_autocmd('VimEnter', {
    group = vim.api.nvim_create_augroup('dotfiles-tree', { clear = true }),
    callback = function()
      local file_arg = vim.fn.argc() > 0 and vim.fn.isdirectory(vim.fn.argv(0)) == 0
      vim.cmd(file_arg and 'Neotree show' or 'Neotree')
    end,
  })

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
