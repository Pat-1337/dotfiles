if has("gui_macvim")
	let macvim_hig_shift_movement = 1
    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
	set termguicolors
	set background=light
endif

set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set autoindent
set number
set relativenumber
set cursorline
hi cursorline cterm=underline term=underline

set ignorecase
set smartcase
set incsearch
set hlsearch
set scrolloff=5
set wildmenu
syntax on

let mapleader=","
nnoremap <leader>gl :YcmCompleter GoToDeclaration<CR>
if has('ide')
    nmap <leader>gl :action GotoImplementation<CR>
endif
nnoremap <leader>gk :YcmCompleter GoToDefinition<CR>
nnoremap <leader>gf :YcmCompleter FixIt<CR>
nnoremap <leader>g; :YcmCompleter GetType<CR>
nnoremap <leader>g' :YcmCompleter GetDoc<CR>

nnoremap <leader>r :NERDTreeFind<CR>

map gn :bn<cr>
map gp :bp<cr>
map gd :bp\|bd #<cr>
map gh :FZF<cr>

nmap <C-h> <C-w>h
nmap <C-j> <C-w>j
nmap <C-k> <C-w>k
nmap <C-l> <C-w>l

let g:NERDTreeNodeDelimiter = "\u00a0"
let g:NERDTreeWinPos = "left"
let g:ycm_clangd_uses_ycmd_caching=0
let g:ycm_clangd_binary_path=exepath("clangd")
let g:ycm_global_ycm_extra_conf='~/.vim/bundle/YouCompleteMe/.ycm_extra_conf.py'
let g:ycm_autoclose_preview_window_after_insertion = 1
let g:ycm_autoclose_preview_window_after_completion = 1

if has('mac')
    vnoremap <C-C> :w !pbcopy<CR><CR>
elseif !empty($WAYLAND_DISPLAY)
    vnoremap <C-C> :w !wl-copy<CR><CR>
else
    vnoremap <C-C> :w !xclip -i -sel c<CR><CR>
endif

set nocompatible
filetype off

set mouse=a

let g:NERDTreeHijackNetrw=0
augroup NERDTreeHijackNetrw
    autocmd VimEnter * silent! autocmd! FileExplorer
augroup END

autocmd VimEnter * call CloseExtraNERDTree()
function CloseExtraNERDTree()
  wincmd l
  let l:main_bufnr = bufnr('%') 
  let l:fname = expand('%')
  if l:fname ==# 'NERD_tree_1'
    exe bufwinnr(l:main_bufnr) . "wincmd w"
    bd
  endif
endfunction

autocmd VimEnter * NERDTree

autocmd VimEnter * NERDTree | wincmd p

autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif

autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') |
    \ execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.argv()[0] | endif

autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

autocmd BufEnter * if bufname('#') =~ 'NERD_tree_\d\+' && bufname('%') !~ 'NERD_tree_\d\+' && winnr('$') > 1 |
    \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute 'buffer'.buf | endif

autocmd BufWinEnter * if getcmdwintype() == '' | silent NERDTreeMirror | endif

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

set rtp+=/opt/homebrew/opt/fzf

Plugin 'VundleVim/Vundle.vim'
Plugin 'preservim/nerdtree'
Plugin 'Valloric/YouCompleteMe'
Plugin 'junegunn/fzf'
Plugin 'bagrat/vim-buffet'
Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}

call vundle#end()
filetype plugin indent on

