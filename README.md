# dotfiles

Configuration files and one setup script. The script supports macOS (arm64),
Debian, Ubuntu, Arch, CachyOS, and Omarchy.

This file uses ASD-STE100 Simplified Technical English.

## Install

```sh
git clone git@github.com:<you>/dotfiles.git ~/Developer/dotfiles
cd ~/Developer/dotfiles
./setup.sh
```

To keep the Omarchy preinstalled apps, add the `--no-debloat` option.

The script asks all questions in the first seconds. Then the installation
continues with no more input from you. The script asks for these items:

- The git author name and the git author email.
- A directory for work repositories, if you want a second git identity.
- The package groups to remove, but only on an Omarchy system.
- A GitHub login, but only if `gh` is not authenticated.

The script asks for the sudo password one time. A background loop keeps the
sudo credential valid. No later step stops for input.

Each package manager runs in its silent mode:

- `DEBIAN_FRONTEND=noninteractive` and the two `--force-conf` options for apt.
- `NONINTERACTIVE=1` for the Homebrew installer.
- `--noconfirm` for pacman, and the three `--answer` options for yay.
- Input from `/dev/null` for the vim and neovim plugin managers.

One step is different. macOS shows a dialog for the Command Line Tools. You
must accept that dialog. The script shows it first, then waits for the
installation to end before it starts Homebrew.

You can run the script again at any time. Before the script replaces a file, it
copies the old file to `<file>.bak.<timestamp>`.

### Identity and automatic runs

This repository is public, so it holds no personal data. The script asks for
your git identity and writes it to `~/.gitconfig`. If you give a directory for
work repositories, the script writes a second identity for it with `includeIf`.
Your personal email address then stays out of your work commits.

To skip a question, set its variable in the environment: `GIT_NAME`,
`GIT_EMAIL`, `GIT_WORK_DIR`, `GIT_WORK_EMAIL`, `DEBLOAT_GROUPS`, or `AUTH_GH`.
To skip all questions, close the standard input: `./setup.sh </dev/null`. The
script then keeps the git identity that is already in the configuration.

The script makes the `~/Developer/bin` directory on all three systems. Both
`.zshrc` files put that directory on the `PATH`. A program that you put there
is then available on all of your machines.

### Files

| File | Destination |
| --- | --- |
| `.zshrc_arm64mac` or `.zshrc_x86linux` | `~/.zshrc` |
| `.vimrc` | `~/.vimrc` |
| `topgrade.toml` | `~/.config/topgrade.toml` |
| `mise.toml` | `~/.config/mise/config.toml` |
| `zed_settings.json` and `zed_keymap.json` | `~/.config/zed/` |
| `iterm2.plist` | iTerm2 preferences (macOS) |

## Secrets

The `.zshrc` files read `~/.secrets` at start. If that file is not present, the
script makes an empty one with mode `400`. If the file is present, the script
does not touch it. The file never moves into or out of this repository.

To change the file, use the `secrets` function:

```sh
secrets
```

The function does these steps:

1. It sets the mode to `600`.
2. It starts your `$EDITOR`.
3. It sets the mode to `400` again when the editor stops.
4. It reads the new values into the current shell.

A zsh `always` block does step 3. The mode returns to `400` even if the editor
gives an error. A graphical editor stops immediately and gives control back to
the shell. To prevent this, the function adds the correct option for such an
editor: `-f` for `mvim` and `gvim`, `--wait` for `zed`, `code`, and `subl`.

## Omarchy

Omarchy supplies the desktop. It gives you Hyprland, Waybar, walker, and mako.
It also installs many apps. The script finds Omarchy and then does these
actions:

- It runs `omarchy-debloat.sh` first. The `--no-debloat` option stops this.
- It keeps the Hyprland stack, the `mpv`, `nautilus`, and `imv` file handlers,
  and `yay`.
- It does not apply the GNOME settings. It removes `vlc` and `dconf-editor`
  from the package list.
- It keeps `~/.config/nvim` if that directory is present, because Omarchy puts
  its LazyVim configuration there.
- It installs `topgrade` with `yay`, and `zed` with pacman. It does not use
  `omarchy-install-zed`, because that command installs `omazed`, and `omazed`
  writes to `settings.json`.

Omarchy puts its `omarchy-*` commands on the `PATH` from its bash
configuration only. So `.zshrc_x86linux` exports `OMARCHY_PATH` and adds
`$OMARCHY_PATH/bin` to the `PATH`. Without this, those commands are not
available in a zsh shell or in an SSH session.

### Removal of the preinstalled apps

The `setup.sh` script starts `omarchy-debloat.sh` for you with the default
groups. You can also start it yourself:

```sh
./omarchy-debloat.sh --dry-run      # show the changes, but change nothing
./omarchy-debloat.sh                # the default groups, with a confirmation
./omarchy-debloat.sh --all --yes    # all groups, with no confirmation
./omarchy-debloat.sh dotnet nvim    # only these groups
```

There are three default groups:

- `apps` removes 1Password, Signal, Spotify, Typora, LibreOffice, OBS Studio,
  Kdenlive, Pinta, Xournal++, LocalSend, Aether, cliamp, and try.
- `webapps` removes the Chromium web app launchers. It also replaces the
  Hyprland key bindings with the plain set.
- `agents` removes the npx command stubs for codex, gemini, copilot, opencode,
  playwright-cli, pi, and ghui.

There are four more groups: `gnome-apps`, `input-method`, `dotnet`, and
`nvim`. The `--help` option shows all of them.

The script gives `pacman -Rns` only the packages that are on the system. One
absent package can therefore not stop the transaction. The script then removes
the orphan packages.

The script keeps these items in all groups:

- `claude-code`, `lazydocker`, and `obsidian`. The Omarchy
  `omarchy-remove-preinstalls` command removes all three, but `setup.sh`
  installs the first two, and you use the third.
- The "Disk Usage" and "Docker" text interface launchers.
- The CUPS packages for printers.
- The Hyprland desktop, and the `gum`, `impala`, `bluetui`, and `wiremix`
  tools that the Omarchy menu needs.

### The post-update hook

The `omarchy-update-perform` command runs the migrations first. Then it runs
the `post-update` hook. Some migrations install apps again, and `cliamp` and
`spotify` both came to the system in this way. Therefore `setup.sh` installs a
hook at `~/.config/omarchy/hooks/post-update.d/dotfiles-debloat`. The hook
applies the removal again after each update. To stop this, delete that file.

> [!NOTE]
> [a-la-carchy](https://github.com/DanielCoffey1/a-la-carchy) is an
> interactive alternative. It is a large text interface. It also sets the
> monitor layout, the power profiles, and the ASUS ROG fan curves. It is good
> for manual work one time. But `setup.sh` can start this script with no
> operator. You can also run this script more than one time safely.

## Tools

The script installs these tools on all three systems:

- Version managers: mise, uv with the ty type checker, and rustup.
- Shell: Oh My Zsh with the syntax-highlight and autosuggestion plugins.
- Editors: Vundle with YouCompleteMe, and kickstart.nvim.
- Agent and version control: Claude Code and gh.
- Services: Docker and PostgreSQL.
- Command line tools: ripgrep, fd, bat, fzf, atuin, zellij, yazi, gitui,
  lazydocker, btop, tealdeer, tokei, topgrade, and pre-commit.

It installs two apps on all three systems: Obsidian and the Helium browser.

| System | Obsidian | Helium |
| --- | --- | --- |
| macOS | `--cask obsidian` | `--cask helium-browser` |
| Arch | `extra/obsidian` | `helium-browser-bin` from the AUR |
| Debian | `deb-get` | the official apt repository |

The AUR is the Arch User Repository. An AUR package needs `yay` or `paru`.
Omarchy supplies `yay`.

### Updates for packages with no repository

The `apt upgrade` command finds a new version only if a repository supplies
one. Topgrade uses apt, so it has the same limit. A `.deb` file that you
download by hand stays at its first version. To prevent this, a package
manager controls each app:

- Helium has an official apt repository at `pkg.helium.computer`. The script
  adds the repository and its signature key. Apt then does all updates.
- Obsidian and LACT supply GitHub releases only. Therefore the script installs
  them with [deb-get](https://github.com/wimpysworld/deb-get). These are
  correct `.deb` packages under dpkg control, and deb-get follows the upstream
  releases. Topgrade has a deb-get step, so `update` includes them. No extra
  configuration is necessary.
- Arch and Omarchy need none of this work. Both `obsidian` and `lact` are in
  the `extra` repository, so pacman controls them.

### Cider

The script does not install Cider, the paid Apple Music app. The
`ciderapp/Cider-2` repository holds no public releases, so no script can
download the Linux build. Use one of these sources:

- The [Cider downloads page](https://cider.sh/downloads). It lists Taproom and
  itch.io. Both need a license.
- Flathub, as `sh.cider.Cider`. The publisher controls this package, and it is
  the only channel with automatic updates. It needs flatpak.

Two packages look correct, but they are not. The AUR `cider` package is a fork
of Cider v1, and it gets no more work. The pacstall `cider-deb` package holds
Cider v1.6.1. Do not use the AUR `cider-2` package. It copies the paid binary
from a private account, and it states the wrong license.

## Clipboard history

Each system gets a clipboard manager, but the tool is different:

| System | Tool | Notes |
| --- | --- | --- |
| macOS | Maccy | The `maccy` cask. |
| Omarchy | walker | Omarchy supplies this. Press SUPER CTRL and V. |
| Other Linux | Ringboard | Rust. It supports X11 and Wayland. |

The script installs no manager on Omarchy. Omarchy has one, and a second
watcher records each copy two times.

On other Linux systems, the Ringboard installer reads `XDG_SESSION_TYPE`. It
then installs the correct watcher and the systemd user services. If your
Wayland compositor has no `ext_data_control_manager_v1` interface, the
installer uses the X11 watcher. The script does this work only in a graphical
session, and only after rustup is available.

The `pbcopy` and `pbpaste` aliases in the `.zshrc` files are different. They
only move text into and out of the clipboard. They keep no history.

## Hardware monitors

| System | Tool | Notes |
| --- | --- | --- |
| Linux | LACT | `extra/lact` on Arch, deb-get on Debian. The script starts the `lactd` service. |
| Linux with NVIDIA | nvtop | The script installs it only if it finds an NVIDIA GPU. |
| macOS | macmon | The equivalent tool for Apple silicon. It needs no sudo. |

To find an NVIDIA GPU, the script does three tests in this order:

1. It looks for the `nvidia-smi` command.
2. It looks for the `/proc/driver/nvidia` directory.
3. It looks for the PCI vendor code `0x10de` in sysfs.

The last test needs no `pciutils` package. The script must know the answer
before it installs the packages.

## Runtime versions

Three tools control the runtimes. Each one holds a different part:

- mise installs Node, Bun, and Go. The `mise.toml` file in this repository
  holds the versions. All machines then run the same versions.
- uv installs Python and Python packages.
- rustup installs Rust.

A project can hold its own `mise.toml` file. The versions in that file are then
correct for the project only.

mise does not control Python here, because uv does that work. mise does not
control Rust, because its Rust support only operates rustup. mise does not
control Java or mono. The macOS Java symlink and the YouCompleteMe Java
completer both need the system packages.

Topgrade has a mise step, so the `update` command also updates the runtimes.

## Python and editors

Use `uv` for all Python work. The type checker is `ty`. The Zed configuration
uses the `ty` and `ruff` language servers. Zed uses Claude Opus 5 as its
default model.
