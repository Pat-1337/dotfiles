# Editors

## Vim

- Plugins come from Vundle. `setup.sh` runs `:PluginInstall`, then compiles
  YouCompleteMe with all completers (clangd, Go, TS/JS, Java, C#, Rust). The
  compile runs only when no `ycm_core*.so` exists yet. It needs node (from
  mise), a JDK, and mono.
- NERDTree opens on the left. With a file argument, the cursor goes to the
  file. With no argument or a directory, the cursor stays in NERDTree. Vim
  exits when NERDTree is the last window. A buffer that tries to replace
  NERDTree opens in the other window instead.
- Tabs are 4 columns and expand to spaces.
- `,bd` closes a buffer. `gd` is Vim's own.
- In MacVim, the colors are 24-bit with a light background.

## Neovim

`setup.sh` installs kickstart.nvim only when `~/.config/nvim` does not exist.
On Omarchy, that directory holds Omarchy's LazyVim, so it is kept. To use
kickstart there, run the debloat `nvim` group, which moves LazyVim to
`~/.config/nvim.omarchy.bak.<timestamp>`, and then run `setup.sh` again.

Every run copies `nvim/dotfiles.lua` to `~/.config/nvim/plugin/dotfiles.lua`,
which loads after `init.lua`. It mirrors the Vim settings above: relative line
numbers, 4-column tabs, `scrolloff=5`, and `gn`/`gp` to change buffers. `gh`
opens Telescope file search where Telescope exists, so LazyVim does not get it.
`g/` searches the whole project for text with Telescope's live grep (ripgrep),
as in Zed. In visual mode it searches for the selection. `<Space>bd` closes a
buffer, and the tab too when the tab has one window. `<Space>tn` opens a new
tab. `Ctrl-o` and `Ctrl-p` go back and forward through the files in the jump
list and skip jumps inside one file, as Zed's back and forward do. They land
where you left each file. `Ctrl-p` stands in for `Ctrl-i`, which the terminal
sends as `Tab`. Within one file, `''` goes back to the last jump, and `g;` and
`g,` walk the change list. netrw's own `Ctrl-h` and `Ctrl-l` keys are turned
off, so those keys move between windows everywhere.

The LSP keys follow Zed's vim mode: `gd` definition, `gD` declaration, `gy`
type definition, `gI` implementation, `gA` references, `g.` code actions,
`gs`/`gS` file and project symbols, `cd` rename, `g]`/`g[` diagnostics, and `K`
hover. They exist only in buffers with a language server, so `gd` elsewhere is
Vim's own. Python uses `ty` and `ruff`, as in Zed. Each one starts if it is on
`PATH`. ruff's hover is off, because ty already answers it. Inlay hints are on
for every server that has them, as in Zed: ty adds variable types
(`Self@from_crawler`) and argument names (`users=`) inline, and rust-analyzer
does the same for Rust. They are italic, in 55% of the text color blended into
the background, set again on every theme change. `<Space>th` turns them off and
on. Rust uses rust-analyzer from rustup (`setup.sh` adds the component), with
`~/.cargo/bin` first on its `PATH`: a Homebrew `rust` would otherwise win, and
it has no `rust-src`, so the standard library would not resolve. Shell scripts
use bash-language-server, with shellcheck for warnings and shfmt for
formatting. Kickstart's Mason installs all three on the first start, and the
server starts when its install ends.

Icons need a Nerd Font. `setup.sh` installs Symbols Nerd Font, which holds only
the icons, and the iTerm2 profile uses it as the non-ASCII font, so text stays
in Menlo. That setting is required. Without it, macOS finds the font on its own
only for the icons above U+FFFF (Rust, Python, Markdown). The folder and most
file icons are in U+E000 to U+F8FF, and those show as `?` boxes. Kickstart
reads `have_nerd_font` before `nvim/dotfiles.lua` runs, so that file sets it
and turns the icons on in mini.icons and the statusline.

A Neo-tree file tree, 30 columns wide, sits on the left, as NERDTree does in
Vim. It opens at start. With a file argument the cursor goes to the file, and
otherwise it stays in the tree. It follows the current file, and nvim quits
when the tree is the last window. `:q` in the tree also quits when the only
other window holds the empty buffer that nvim starts with. With a file open, it
closes only the tree. Each new tab gets its own copy of the tree, because Vim
tabs cannot share a window. `Shift+Enter` (or `t`) in the tree opens a file in
a new tab. Shift+Enter needs a terminal that reports it apart from Enter.
`<Space>tw` saves the files in the current tab only. `<Space>tq` closes the tab
and discards its unsaved changes. In the last tab it quits, but still asks
about unsaved files in other buffers. Plain `:q!` does not close a tab cleanly,
because Neo-tree refuses to close a tree beside a modified file, and
`:tabclose!` keeps the changes in memory. `Tab` reveals the current file in the
tree, as Zed's `RevealInProjectPanel` does, and `Tab` in the tree goes back. In
the tree, `Enter` opens a file, and the keys follow the Zed project panel
keymap: `a` new file, `A` new directory, `r` rename, `d` delete, `x` cut, `c`
copy, `p` paste, `h`/`l`/`o` and `zc`/`zo` collapse and expand, `Y` and `gy`
copy the relative and full path. `/` filters the tree by name. `gh` searches
all files.

In netrw (`:Ex`), `gh` searches the browsed directory, and `g.` shows or hides
dot-files, because netrw's own `gh` did that.

Each file window has a header bar (`winbar`): the path from the git root, or
from the working directory outside a repository, with the folders faint and a
`●` for unsaved changes. On the right it shows the size on disk, the encoding,
and the line ending format. The tree, Telescope, and floating windows get no
header. `<Space>yr` copies the relative path to the system clipboard, and
`<Space>ya` the absolute one.

Inline git blame shows on the cursor line after 300 ms, as Zed does: `author,
time ago • summary` after the end of the line. Its color is 45% of the theme's
text color blended into the background, with no background of its own, so it
reads as faint text over the cursor line too. It is set again on every theme
change. `<Space>tb` turns it off and on.

The theme is Kanagawa Wave in dark mode and Dayfox in light mode. On a local
Mac, auto-dark-mode.nvim follows the system appearance, including the Auto
setting that changes at sunrise and sunset. The first check runs before the
first screen draws, so kickstart's Tokyo Night never shows. Elsewhere (Linux,
SSH) the theme goes by the clock: light from 07:00 to 19:00. LazyVim keeps its
own theme.

## Helix

`helix/languages.toml` sets a new source for the `gotmpl` grammar. Helix
25.07.1 pins it to `dannylongeuay/tree-sitter-go-template`, which has been
deleted, so `hx --grammar fetch` fails. Upstream moved it to `ngalaiko`.
Remove this block when a Helix release has the new source.

## Zed

Python uses the `ty` and `ruff` language servers. Format on save is off. A
manual format runs ruff: organize imports, fix, then format. The default
agent model is Claude Opus 5.

Zed comes from pacman on Arch, not from `omarchy-install-zed`. That command
installs `omazed`, which writes to `settings.json`.
