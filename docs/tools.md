# Tools and apps

## Installed everywhere

- Version managers: mise, uv with the ty type checker, rustup.
- Shell: Oh My Zsh with zsh-syntax-highlighting and zsh-autosuggestions.
- Editors: Helix, Vim with Vundle and YouCompleteMe, kickstart.nvim.
- Claude Code and gh.
- Services: Docker and PostgreSQL. On Linux, also colima from Homebrew.
- CLI: ripgrep, fd, bat, fzf, atuin, zellij, yazi, gitui, lazydocker, btop,
  tealdeer, tokei, topgrade, pre-commit, tree-sitter-cli.
- Font: Symbols Nerd Font, for the icons in Neovim. Homebrew cask on macOS,
  `ttf-nerd-fonts-symbols-mono` on Arch, and the GitHub release in
  `~/.local/share/fonts` on Debian.

## Apps

Obsidian and the Helium browser, on every system:

| System | Obsidian | Helium |
| --- | --- | --- |
| macOS | `--cask obsidian` | `--cask helium-browser` |
| Arch | `extra/obsidian` | `helium-browser-bin` from the AUR |
| Debian | `deb-get` | the official apt repository |

An AUR package needs `yay` or `paru`. Omarchy has `yay`.

### Apps with no apt repository

`apt upgrade` only finds a new version that a repository supplies, and
topgrade goes through apt, so a hand-installed `.deb` stays at its first
version. So every app has a package manager behind it:

- Helium has an official apt repository at `pkg.helium.computer`. The script
  adds it and its signing key, and apt does the updates.
- Obsidian and LACT only publish GitHub releases, so
  [deb-get](https://github.com/wimpysworld/deb-get) installs them. They are
  real `.deb` packages under dpkg, deb-get follows the upstream releases, and
  topgrade has a deb-get step.
- On Arch and Omarchy, `obsidian` and `lact` are in `extra`, so pacman owns
  them.

## Clipboard history

| System | Tool | Notes |
| --- | --- | --- |
| macOS | Maccy | The `maccy` cask. |
| Omarchy | walker | Built in. SUPER CTRL V. |
| Other Linux | Ringboard | Rust. X11 and Wayland. |

Nothing is installed on Omarchy, because a second watcher would record every
copy twice. For how Ringboard is installed, see [setup.md](setup.md).

The `pbcopy` and `pbpaste` aliases only move text in and out of the
clipboard. They keep no history.

## Hardware monitors

| System | Tool | Notes |
| --- | --- | --- |
| Linux | LACT | `extra/lact` on Arch, deb-get on Debian. The `lactd` service is enabled. |
| Linux with NVIDIA | nvtop | Only when an NVIDIA GPU is found. |
| macOS | macmon | The Apple silicon equivalent. No sudo. |

For how the NVIDIA GPU is found, see [setup.md](setup.md).

## Cider

Cider, the paid Apple Music app, is not installed. The `ciderapp/Cider-2`
repository has no public releases, so no script can download the Linux build.
Get it from:

- The [Cider downloads page](https://cider.sh/downloads), which lists Taproom
  and itch.io. Both need a license.
- Flathub, as `sh.cider.Cider`. The publisher maintains it, and it is the only
  channel with automatic updates. It needs flatpak.

These packages look right but are not:

- The AUR `cider` package is a fork of Cider v1, and it is abandoned.
- The pacstall `cider-deb` package is Cider v1.6.1.
- The AUR `cider-2` package copies the paid binary from a private account and
  states the wrong license. Do not use it.
