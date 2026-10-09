vim.o.relativenumber = true
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.o.scrolloff = 5

vim.keymap.set('n', '/', function() return '/' .. vim.fn.escape(vim.fn.expand '<cword>', [[\/.*$^~[]]) end, { expr = true, desc = 'Search, starting with the word under the cursor' })
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
if pcall(require, 'telescope.builtin') then
  vim.keymap.set('n', 'gh', function() require('telescope.builtin').find_files() end, { desc = 'Find files' })
  vim.keymap.set('n', 'g/', function() require('telescope.builtin').live_grep() end, { desc = 'Search the project' })
  vim.keymap.set('x', 'g/', function() require('telescope.builtin').grep_string() end, { desc = 'Search the project for the selection' })
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

local function jump_file(back)
  if vim.bo.filetype == 'neo-tree' then vim.cmd.wincmd 'p' end
  local list, idx = unpack(vim.fn.getjumplist())
  local pos, current = idx + 1, vim.api.nvim_get_current_buf()
  local first, last, step = pos + 1, #list, 1
  if back then first, last, step = pos - 1, 1, -1 end
  for i = first, last, step do
    local buf = list[i].bufnr
    if buf ~= current and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' then
      while not back and list[i + 1] and list[i + 1].bufnr == buf do i = i + 1 end
      local keys = back and '\15' or '\t'
      return vim.cmd('normal! ' .. math.abs(i - pos) .. keys)
    end
  end
end
vim.keymap.set('n', '<C-o>', function() jump_file(true) end, { desc = 'Back to the previous file' })
vim.keymap.set('n', '<C-p>', function() jump_file(false) end, { desc = 'Forward to the next file' })

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
  vim.cmd(vim.fn.tabpagenr '$' > 1 and 'tabclose' or 'confirm qall')
end, { desc = '[T]ab [Q]uit: close this tab, discarding its changes' })

vim.keymap.set('n', '<Plug>(dotfiles-netrw-hide)', '<Plug>NetrwHideEdit')
vim.keymap.set('n', '<Plug>(dotfiles-netrw-refresh)', '<Plug>NetrwRefresh')

local function blend(fg, bg, alpha)
  local out = 0
  for _, shift in ipairs { 16, 8, 0 } do
    local a, b = bit.band(bit.rshift(fg, shift), 255), bit.band(bit.rshift(bg, shift), 255)
    out = out + bit.lshift(math.floor(a * alpha + b * (1 - alpha) + 0.5), shift)
  end
  return out
end
local function faint_colors()
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  local function faint(group, alpha, italic)
    if normal.fg and normal.bg then
      vim.api.nvim_set_hl(0, group, { fg = blend(normal.fg, normal.bg, alpha), italic = italic })
    else
      vim.api.nvim_set_hl(0, group, { link = 'Comment' })
    end
  end
  faint('GitSignsCurrentLineBlame', 0.45, false)
  faint('LspInlayHint', 0.55, true)
  faint('DotfilesWinbarDir', 0.6, false)
end
faint_colors()
vim.api.nvim_create_autocmd('ColorScheme', { group = vim.api.nvim_create_augroup('dotfiles-faint', { clear = true }), callback = faint_colors })

local function project_path(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  local root = vim.fs.root(buf, '.git') or vim.fn.getcwd()
  return vim.fs.relpath(root, name) or vim.fn.fnamemodify(name, ':~')
end

local function human_size(bytes)
  if bytes < 0 then return 'new file' end
  for _, unit in ipairs { 'B', 'KiB', 'MiB' } do
    if bytes < 1024 or unit == 'MiB' then return (unit == 'B' and '%d %s' or '%.1f %s'):format(bytes, unit) end
    bytes = bytes / 1024
  end
end

function DotfilesWinbar(win)
  if not vim.api.nvim_win_is_valid(win) then return '' end
  local buf = vim.api.nvim_win_get_buf(win)
  local path = project_path(buf):gsub('%%', '%%%%')
  local dir, file = path:match '^(.*/)([^/]+)$'
  if not dir then dir, file = '', path end
  local encoding = vim.bo[buf].fileencoding ~= '' and vim.bo[buf].fileencoding or vim.o.encoding
  local meta = ('%s  %s %s'):format(human_size(vim.fn.getfsize(vim.api.nvim_buf_get_name(buf))), encoding, vim.bo[buf].fileformat)
  return (' %%#DotfilesWinbarDir#%s%%*%s%s%%=%%#DotfilesWinbarDir#%s '):format(dir, file, vim.bo[buf].modified and ' ●' or '', meta)
end

local function set_winbar(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local file = vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= '' and vim.api.nvim_win_get_config(win).relative == ''
  vim.wo[win].winbar = file and ('%%{%%v:lua.DotfilesWinbar(%d)%%}'):format(win) or ''
end
vim.api.nvim_create_autocmd({ 'BufWinEnter', 'FileType', 'WinEnter', 'VimEnter' }, {
  group = vim.api.nvim_create_augroup('dotfiles-winbar', { clear = true }),
  callback = function()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do set_winbar(win) end
  end,
})

local function copy_file_path(absolute)
  local buf = vim.api.nvim_get_current_buf()
  local path = absolute and vim.api.nvim_buf_get_name(buf) or project_path(buf)
  vim.fn.setreg('+', path)
  vim.notify('Copied ' .. path)
end
vim.keymap.set('n', '<leader>yr', function() copy_file_path(false) end, { desc = '[Y]ank [R]elative path' })
vim.keymap.set('n', '<leader>ya', function() copy_file_path(true) end, { desc = '[Y]ank [A]bsolute path' })

local watchers = {}
local function unwatch(buf)
  local w = watchers[buf]
  if not w then return end
  w.handle:stop()
  w.handle:close()
  w.timer:stop()
  w.timer:close()
  watchers[buf] = nil
end
local function watch(buf)
  unwatch(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if path == '' or vim.bo[buf].buftype ~= '' or vim.fn.filereadable(path) == 0 then return end
  local handle, timer = vim.uv.new_fs_event(), vim.uv.new_timer()
  watchers[buf] = { handle = handle, timer = timer }
  handle:start(path, {}, function()
    timer:stop()
    timer:start(5000, 0, vim.schedule_wrap(function()
      if not vim.api.nvim_buf_is_valid(buf) then return unwatch(buf) end
      vim.cmd.checktime(buf)
      watch(buf)
    end))
  end)
end
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'BufFilePost' }, {
  group = vim.api.nvim_create_augroup('dotfiles-watch', { clear = true }),
  callback = function(ev) watch(ev.buf) end,
})
vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
  group = 'dotfiles-watch',
  callback = function(ev) unwatch(ev.buf) end,
})
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) then watch(buf) end
end

local function refresh_hints(buf)
  if not vim.lsp.inlay_hint.is_enabled { bufnr = buf } then return end
  vim.lsp.inlay_hint.enable(false, { bufnr = buf })
  vim.schedule(function() vim.lsp.inlay_hint.enable(true, { bufnr = buf }) end)
end
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  group = vim.api.nvim_create_augroup('dotfiles-hints-reload', { clear = true }),
  callback = function(ev) refresh_hints(ev.buf) end,
})
vim.api.nvim_create_autocmd('LspProgress', {
  group = vim.api.nvim_create_augroup('dotfiles-hints-indexed', { clear = true }),
  pattern = 'end',
  callback = function(ev)
    if ev.data.params.value.title ~= 'Indexing' then return end
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    for buf in pairs(client and client.attached_buffers or {}) do refresh_hints(buf) end
  end,
})
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('dotfiles-lsp-keys', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.name == 'ruff' then client.server_capabilities.hoverProvider = false end
    if client and client:supports_method 'textDocument/inlayHint' then vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf }) end
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
vim.lsp.config('rust_analyzer', { cmd_env = { PATH = vim.fs.normalize '~/.cargo/bin' .. ':' .. vim.env.PATH } })
for server, cmd in pairs { ty = 'ty', ruff = 'ruff', rust_analyzer = 'rust-analyzer', bashls = 'bash-language-server' } do
  if vim.fn.executable(cmd) == 1 then vim.lsp.enable(server) end
end
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

if vim.pack and not package.loaded.lazy then
  vim.g.have_nerd_font = true
  if pcall(require, 'mini.icons') then
    require('mini.icons').setup()
    MiniIcons.mock_nvim_web_devicons()
    if MiniStatusline then MiniStatusline.config.use_icons = true end
  end

  vim.pack.add { 'https://github.com/rebelot/kanagawa.nvim', 'https://github.com/EdenEast/nightfox.nvim' }

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
    default_component_configs = { container = { enable_character_fade = false } },
    window = {
      position = 'left',
      width = 30,
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
  vim.api.nvim_create_autocmd('TabNewEntered', {
    group = vim.api.nvim_create_augroup('dotfiles-tree-tabs', { clear = true }),
    callback = function() vim.schedule(function() vim.cmd 'Neotree show' end) end,
  })
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

  local has_gitsigns, gitsigns = pcall(require, 'gitsigns')
  if has_gitsigns then
    local config = require('gitsigns.config').config
    config.current_line_blame_opts = { delay = 300 }
    config.current_line_blame_formatter = '    <author>, <author_time:%R> • <summary>'
    gitsigns.toggle_current_line_blame(true)
  end

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
    local function by_clock()
      local hour = tonumber(os.date '%H')
      apply((hour >= 7 and hour < 19) and 'light' or 'dark')
    end
    by_clock()
    vim.uv.new_timer():start(60000, 60000, vim.schedule_wrap(by_clock))
  end
end
