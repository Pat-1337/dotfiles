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
- In MacVim, the colors are 24-bit with a light background.

## Neovim

`setup.sh` installs kickstart.nvim only when `~/.config/nvim` does not exist.
On Omarchy, that directory holds Omarchy's LazyVim, so it is kept. To use
kickstart there, run the debloat `nvim` group, which moves LazyVim to
`~/.config/nvim.omarchy.bak`, and then run `setup.sh` again.

Every run copies `nvim_dotfiles.lua` to `~/.config/nvim/plugin/dotfiles.lua`,
which loads after `init.lua`. It mirrors the Vim settings above: relative
line numbers, 4-column tabs, `scrolloff=5`, and the `gn`/`gp`/`gd` buffer
maps. `gh` opens Telescope file search where Telescope exists, so LazyVim
does not get it.

## Helix

`helix_languages.toml` sets a new source for the `gotmpl` grammar. Helix
25.07.1 pins it to `dannylongeuay/tree-sitter-go-template`, which has been
deleted, so `hx --grammar fetch` fails. Upstream moved it to `ngalaiko`.
Remove this block when a Helix release has the new source.

## Zed

Zed comes from pacman on Arch, not from `omarchy-install-zed`. That command
installs `omazed`, which writes to `settings.json`.
