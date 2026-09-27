# setup.sh

```sh
./setup.sh [--no-debloat]
```

Supports macOS (arm64), Debian/Ubuntu, and Arch/CachyOS/Omarchy.

## Questions first, then unattended

Every question comes at the start. After you confirm, nothing else blocks, so
you can start the script and walk away. The only later prompt is the optional
`gh auth login` at the very end.

A question is skipped when its answer is already on the machine:

- git identity: `user.name` and `user.email` in `~/.gitconfig`
- work identity: any `includeIf.gitdir` rule. It is offered only during
  first-time git setup, because a declined answer leaves nothing behind and
  would otherwise be asked on every run.
- GitHub login: `gh auth status` succeeds. It usually does, because cloning
  this repository needed it.

Preset any answer through the environment: `GIT_NAME`, `GIT_EMAIL`,
`GIT_WORK_DIR`, `GIT_WORK_EMAIL`, `DEBLOAT_GROUPS`, `AUTH_GH`. Run
`./setup.sh </dev/null` to skip all questions. The script then keeps what is
already configured. It never writes an empty email.

The work identity goes to `~/.gitconfig-work` through `includeIf`, so a
personal email cannot leak into work commits.

`ask` uses `read -p`, which writes the prompt to stderr, so command
substitution captures only the answer.

## sudo

- Linux: one password prompt at the start, refreshed in the background every
  50 seconds. A failed refresh does not stop the loop, because the credential
  can come back (see `resudo`). If sudo already works without a password, no
  prompt is shown.
- macOS: no prompt up front. Homebrew runs `sudo --reset-timestamp` on every
  brew command, so an early credential never survives to the one step that
  needs it (the Java symlink). `resudo` asks at the point of use, and only when
  the credential is really gone.
- Never run the script with sudo. It refuses to run as root.

## Order of steps

1. Omarchy only: `omarchy-debloat.sh`, before any installs.
2. System packages for the platform.
3. `common_toolchains`: uv, then rustup. This must come before the per-distro
   CLI tools, which fall back to `cargo install`.
4. Per-distro extras, then colima (Linux).
5. `common_stack`: `~/Developer/bin`, git identity, Claude Code, Oh My Zsh,
   dotfiles, mise runtimes, Vim + YouCompleteMe, Neovim.
6. `use_zsh` (Linux).
7. `topgrade -y`, then the optional GitHub login.

mise runs before Vim, because YouCompleteMe builds a JavaScript completer and
needs node.

## Files

| Repository file | Destination |
| --- | --- |
| `.zshrc_arm64mac` / `.zshrc_x86linux` | `~/.zshrc` |
| `omarchy.zsh` | `~/.config/zsh/omarchy.zsh` (Omarchy only) |
| `.vimrc` | `~/.vimrc` |
| `topgrade.toml` | `~/.config/topgrade.toml` (Omarchy gets a variant, see omarchy.md) |
| `mise.toml` | `~/.config/mise/conf.d/dotfiles.toml` |
| `zed_settings.json`, `zed_keymap.json` | `~/.config/zed/` |
| `helix_languages.toml` | `~/.config/helix/languages.toml` |

A destination that differs from the repository copy is saved as
`<file>.bak.<timestamp>` first.

`~/.secrets` is created empty with mode 400 and is never copied into or out of
this public repository.

## Oh My Zsh

The Oh My Zsh installer quits when zsh is missing. The plugin clones after it
still create `~/.oh-my-zsh/custom`, and on the next run the installer refuses
the existing folder. So a `~/.oh-my-zsh` without `oh-my-zsh.sh` is moved to
`~/.oh-my-zsh.incomplete.<timestamp>`, Oh My Zsh is installed, and the plugins
are copied back. Nothing is deleted.

## Default shell (Linux)

`use_zsh` changes the login shell only when both are true:

- zsh is installed
- `zsh -i -c exit` finishes with no output and no error, so the new
  `~/.zshrc` starts cleanly

Otherwise the shell stays as it is, and the reason is printed. The current
shell is read from passwd, not `$SHELL`, because `$SHELL` belongs to the
session that started the script. zsh is added to `/etc/shells` if it is
missing. Log out and in after the change.

## macOS notes

- Xcode Command Line Tools: the GUI installer runs detached, so the script
  waits for it. Homebrew needs a compiler. This is the one step that cannot be
  automated, and it is the first one.
- Homebrew is installed with `NONINTERACTIVE=1`, or it waits for RETURN.
- A cask install fails if the app is already in `/Applications`, so that is
  checked first.

## Debian notes

- apt runs with `DEBIAN_FRONTEND=noninteractive` and `--force-confold
  --force-confdef`, so debconf and changed config files never prompt.
- `fdfind` and `batcat` get `fd` and `bat` symlinks in `~/.local/bin`.
- Rust CLI tools come from apt when the distro has them, cargo otherwise.
  apt's `tree-sitter-cli` is too old for nvim-treesitter's main branch, so it
  always comes from cargo.
- helix comes from apt, because a cargo build has no runtime directory and
  therefore no grammars.
- mise: `extrepo` first, because it keeps the key out of the script's hands.
  Not every release has a mise recipe, so the fallback is mise's own apt
  repository.
- Neovim comes from the official tarball and fzf from git. The apt versions
  are too old for kickstart.nvim and for `fzf --zsh`.
- Obsidian and LACT have no apt repository, and a hand-installed `.deb` never
  updates. deb-get follows their GitHub releases and installs real `.deb`
  packages through dpkg. topgrade has a deb-get step.
- Homebrew needs `procps` and `file`, so both are in the apt list.

## Arch notes

- `yay` (Omarchy) or `paru` (some CachyOS installs) handles the AUR packages:
  Helium and topgrade.
- `python-virtualenvwrapper` is AUR-only, so pipx installs it instead. That
  keeps it out of the pacman transaction.
- `vlc` and `dconf-editor` are added only outside Omarchy.
- For package conflicts and the Omarchy pacman guard, see
  [omarchy.md](omarchy.md).

## Linux, all distros

- NVIDIA detection, in order: `nvidia-smi`, `/proc/driver/nvidia`, PCI vendor
  `0x10de` in sysfs. It reads sysfs instead of running `lspci`, because
  pciutils may not be installed yet when the package list is built. nvtop is
  installed only on NVIDIA.
- LACT's GUI talks to `lactd` over a socket, so the daemon is enabled.
- Clipboard history: Ringboard outside Omarchy. Its installer picks the X11 or
  Wayland watcher, writes the systemd user units, and handles compositors
  without `ext_data_control_manager_v1`. It needs cargo. Omarchy already has
  walker's clipboard (SUPER CTRL V), and a second watcher would record every
  copy twice.
- Colima is in neither the Arch nor the Debian repositories. Homebrew on Linux
  (`/home/linuxbrew`) installs it with lima and qemu, and topgrade's brew step
  updates it. See [shell.md](shell.md) for why brew goes last on `PATH`.
- `~/Developer/bin` is the macOS convention. Both `.zshrc` files put it on
  `PATH`, so the layout is the same on Linux.
