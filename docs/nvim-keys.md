# Neovim keys

The keys that `nvim/dotfiles.lua` adds or changes. `<Space>` is the leader key.

## Files and buffers

| Key | Action |
| --- | --- |
| `gh` | Search files (Telescope). In netrw, searches the folder being browsed |
| `g/` | Search the whole project for text, live as you type. In visual mode, for the selection |
| `gn` / `gp` | Next / previous buffer |
| `<Space>bd` | Close the buffer, and its tab if the tab has one window |
| `Ctrl-o` / `Ctrl-p` | Back / forward through files only, to where you left each one |
| `<Space>yr` / `<Space>ya` | Copy the file's path to the clipboard: relative to the project / absolute |

## Tabs

| Key | Action |
| --- | --- |
| `<Space>tn` | New tab |
| `<Space>tw` | Save the files in this tab |
| `<Space>tq` | Close this tab and discard its changes. The last tab quits nvim |
| `gt` / `gT` | Next / previous tab |

## File tree

| Key | Action |
| --- | --- |
| `Tab` | Reveal the current file in the tree. In the tree, back to the file |
| `Enter`, `l`, `o`, `zo` | Open the file, or expand the folder |
| `Shift-Enter`, `t` | Open the file in a new tab |
| `h`, `zc` | Collapse the folder |
| `a` / `A` | New file / new folder |
| `r` | Rename |
| `d` | Delete |
| `x` / `c` / `p` | Cut / copy / paste |
| `Y` / `gy` | Copy the relative / full path |
| `/` | Filter the tree by name |
| `:q` | Quits nvim when the only other window is the empty start buffer |

## Code (with a language server)

These follow Zed's vim mode. Without a language server, `gd` is Vim's own.

| Key | Action |
| --- | --- |
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gy` | Go to type definition |
| `gI` | Go to implementation |
| `gA` | Find all references |
| `g.` | Code actions |
| `gs` / `gS` | Symbols in the file / in the project |
| `cd`, `grn` | Rename the symbol under the cursor, only where the language server says it is used |
| `K` | Hover |
| `g]` / `g[`, `]d` / `[d` | Next / previous diagnostic |

## Toggles

| Key | Action |
| --- | --- |
| `<Space>tb` | Inline git blame |
| `<Space>th` | Inlay hints (types and argument names) |

## netrw (`:Ex`)

| Key | Action |
| --- | --- |
| `gh` | Search the browsed folder |
| `g.` | Show or hide dot-files |
| `Ctrl-h` / `Ctrl-l` | Move between windows, as everywhere else |

## Useful built-ins

| Key | Action |
| --- | --- |
| `''` | Back to the last jump inside the file |
| `g;` / `g,` | Older / newer change |
| `Ctrl-h/j/k/l` | Move between windows |
| `<Space>sf` | Search files (Telescope) |
| `Ctrl-w T` | Move the window to a new tab |
| `Ctrl-^` | Previous buffer |

## Vim

In Vim the leader is `,`. `,bd` closes a buffer, and `gn` / `gp` change buffers.
