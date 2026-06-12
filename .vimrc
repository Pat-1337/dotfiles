if has("gui_macvim")
	let macvim_hig_shift_movement = 1
	" colorscheme NeoSolarized
    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
	set termguicolors
	set background=light
endif

set tabstop=4       " The width of a TAB is set to 4.
                    " Still it is a \t. It is just that
                    " Vim will interpret it to be having
                    " a width of 4.
set shiftwidth=4    " Indents will have a width of 4
set softtabstop=4   " Sets the number of columns for a TAB
set expandtab       " Expand TABs to spaces
set autoindent
set number
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

vnoremap <C-C> :w !xclip -i -sel c<CR><CR>

set nocompatible              " be iMproved, required
filetype off                  " required

set mouse=a

" Highjack nerdtree's highjacking to keep normal nerdtree from loading on directories
let g:NERDTreeHijackNetrw=0
augroup NERDTreeHijackNetrw
    autocmd VimEnter * silent! autocmd! FileExplorer
augroup END

autocmd VimEnter * call CloseExtraNERDTree()
" If vim is started with a file, simply show that file
" If vim is started with nothing or a directory close extra NERDTree buffer
function CloseExtraNERDTree()
  wincmd l " move to right pane
  let l:main_bufnr = bufnr('%') 
  let l:fname = expand('%') " get name of current buffer
  if l:fname ==# 'NERD_tree_1'
    exe bufwinnr(l:main_bufnr) . "wincmd w"
    bd
  endif
endfunction

" Start NERDTree and leave the cursor in it.
autocmd VimEnter * NERDTree

" Start NERDTree and put the cursor back in the other window.
autocmd VimEnter * NERDTree | wincmd p

" Start NERDTree. If a file is specified, move the cursor to its window.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif

" Start NERDTree when Vim starts with a directory argument.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') |
    \ execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.argv()[0] | endif

" Exit Vim if NERDTree is the only window remaining in the only tab.
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

" Close the tab if NERDTree is the only window remaining in it.
autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

" If another buffer tries to replace NERDTree, put it in the other window, and bring back NERDTree.
autocmd BufEnter * if bufname('#') =~ 'NERD_tree_\d\+' && bufname('%') !~ 'NERD_tree_\d\+' && winnr('$') > 1 |
    \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute 'buffer'.buf | endif

" Open the existing NERDTree on each new tab.
autocmd BufWinEnter * if getcmdwintype() == '' | silent NERDTreeMirror | endif

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

set rtp+=/opt/homebrew/opt/fzf

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'preservim/nerdtree'
Plugin 'Valloric/YouCompleteMe'
Plugin 'junegunn/fzf'
Plugin 'bagrat/vim-buffet'
" The following are examples of different formats supported.
" Keep Plugin commands between vundle#begin/end.
" plugin on GitHub repo
" Plugin 'tpope/vim-fugitive'
" plugin from http://vim-scripts.org/vim/scripts.html
" Plugin 'L9'
" Git plugin not hosted on GitHub
" Plugin 'git://git.wincent.com/command-t.git'
" git repos on your local machine (i.e. when working on your own plugin)
" Plugin 'file:///home/gmarik/path/to/plugin'
" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
" Install L9 and avoid a Naming conflict if you've already installed a
" different version somewhere else.
" Plugin 'ascenator/L9', {'name': 'newL9'}

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line


