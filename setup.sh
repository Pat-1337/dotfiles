#!/usr/bin/env bash

### Dotfiles setup — macOS (arm64), Debian/Ubuntu, Arch/CachyOS/Omarchy
###
### Usage: ./setup.sh [--no-debloat]
###
### Every question is asked up front, then the install runs unattended — start it
### and walk away. Nothing personal is stored in this repo: the git identity is
### prompted for and written to ~/.gitconfig, and ~/.secrets never leaves $HOME.
###
### A question is skipped when the answer is already on the machine: a git
### identity in ~/.gitconfig, an includeIf rule for work repos, or an
### authenticated gh. To change one of those, edit it with git config, or preset
### GIT_NAME, GIT_EMAIL, GIT_WORK_DIR, GIT_WORK_EMAIL, DEBLOAT_GROUPS or
### AUTH_GH in the environment. Pipe from /dev/null to skip every question.
###
### On Omarchy, ./omarchy-debloat.sh runs first — it strips the preinstalled app
### layer (see that script's --help for the groups) so this script installs the
### toolchain instead. --no-debloat skips that pass.

set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBLOAT=1

for arg in "$@"; do
    case "$arg" in
    --no-debloat) DEBLOAT=0 ;;
    *) echo "Usage: ${0##*/} [--no-debloat]" >&2; exit 1 ;;
    esac
done

have() { command -v "$1" >/dev/null; }

# apt prompts through debconf and on changed config files unless told otherwise
apt_get() {
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y \
        -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef "$@"
}

# A cask install aborts if the app is already in /Applications, so check first
install_cask() {
    [ -d "/Applications/$2.app" ] && return 0
    brew install --cask "$1"
}

# `read -p` writes the prompt to stderr, so command substitution stays clean
ask() {
    local prompt="$1" default="${2:-}" reply
    if [ -n "$default" ]; then
        read -r -p "$prompt [$default]: " reply </dev/tty
    else
        read -r -p "$prompt: " reply </dev/tty
    fi
    echo "${reply:-$default}"
}
info() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
is_omarchy() { [ -d "$HOME/.local/share/omarchy" ] || have omarchy-update; }

# 0x10de is NVIDIA's PCI vendor id. Read from sysfs rather than shelling out to
# lspci, which needs pciutils — not yet installed when the package list is built.
has_nvidia() {
    have nvidia-smi && return 0
    [ -d /proc/driver/nvidia ] && return 0
    grep -qil 0x10de /sys/bus/pci/devices/*/vendor 2>/dev/null
}

if [ "$(id -u)" -eq 0 ]; then
    echo "Don't run setup.sh with sudo — run it as your user." >&2
    exit 1
fi

### Everything interactive lives here — the rest of the run must not block.
### A question is only asked when its answer is not already on the machine.

# A previous run, or the user, may already have an includeIf rule for work repos
has_git_work_identity() {
    git config --global --name-only --get-regexp '^includeIf\.gitdir' >/dev/null 2>&1
}

collect_inputs() {
    GIT_NAME="${GIT_NAME:-$(git config --global user.name 2>/dev/null)}"
    GIT_EMAIL="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null)}"
    GIT_WORK_DIR="${GIT_WORK_DIR:-}"
    GIT_WORK_EMAIL="${GIT_WORK_EMAIL:-}"
    DEBLOAT_GROUPS="${DEBLOAT_GROUPS:-default}"
    AUTH_GH="${AUTH_GH:-ask}"

    # gh is usually already authenticated: cloning this repo needed it
    if [ "$AUTH_GH" = ask ] && have gh && gh auth status >/dev/null 2>&1; then
        AUTH_GH=authed
    fi

    if [ ! -t 0 ]; then
        info "Non-interactive — keeping the existing git identity and default groups"
        [ "$AUTH_GH" = ask ] && AUTH_GH=no
        return 0
    fi

    # Work out what is missing before printing anything, so a fully configured
    # machine shows no questions at all.
    local ask_identity=0 ask_work=0 ask_debloat=0 ask_gh=0
    { [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; } || ask_identity=1

    # The work identity has nothing to remember when it is declined, so only
    # offer it during first-time git setup. Otherwise it would ask on every run.
    if [ -n "$GIT_WORK_DIR" ]; then
        [ -z "$GIT_WORK_EMAIL" ] && ask_work=1
    elif ((ask_identity)) && ! has_git_work_identity; then
        ask_work=1
    fi

    is_omarchy && ((DEBLOAT)) && ask_debloat=1
    [ "$AUTH_GH" = ask ] && ask_gh=1

    if ((ask_identity || ask_work || ask_debloat || ask_gh)); then
        info "Setup questions (everything after this runs unattended)"
    fi

    if ((ask_identity)); then
        GIT_NAME="$(ask "Git author name" "$GIT_NAME")"
        GIT_EMAIL="$(ask "Git author email" "$GIT_EMAIL")"
    fi

    if ((ask_work)); then
        [ -n "$GIT_WORK_DIR" ] ||
            GIT_WORK_DIR="$(ask "Directory for work repos, for a separate git identity (blank to skip)")"
        [ -n "$GIT_WORK_DIR" ] && [ -z "$GIT_WORK_EMAIL" ] &&
            GIT_WORK_EMAIL="$(ask "Git email inside $GIT_WORK_DIR")"
    fi

    if ((ask_debloat)); then
        echo "Omarchy debloat: 'default' (apps webapps agents), 'all', 'skip', or a group list."
        DEBLOAT_GROUPS="$(ask "Debloat groups" "$DEBLOAT_GROUPS")"
    fi

    if ((ask_gh)); then
        case "$(ask "Log in to GitHub at the end? Needs a browser (y/n)" y)" in
        [yY]*) AUTH_GH=yes ;;
        *) AUTH_GH=no ;;
        esac
    fi

    echo
    echo "  git identity   : ${GIT_NAME:-<unset>} <${GIT_EMAIL:-unset}>"
    if [ -n "$GIT_WORK_DIR" ]; then
        echo "  work identity  : <$GIT_WORK_EMAIL> inside $GIT_WORK_DIR"
    elif has_git_work_identity; then
        echo "  work identity  : already configured"
    fi
    is_omarchy && ((DEBLOAT)) && echo "  omarchy debloat: $DEBLOAT_GROUPS"
    case "$AUTH_GH" in
    authed) echo "  github login   : already authenticated" ;;
    *) echo "  github login   : $AUTH_GH" ;;
    esac

    # Nothing was asked, so nothing needs confirming — do not block the run
    if ((ask_identity || ask_work || ask_debloat || ask_gh)); then
        read -r -p "
Press Enter to start, Ctrl-C to abort. " </dev/tty
    fi
}

# One password prompt, refreshed in the background, so no step blocks later on.
# The parent process drives the loop. A failed refresh must not end it, because
# the credential can come back — see resudo.
sudo_keepalive() {
    info "Asking for sudo once"
    sudo -v || exit 1
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
    SUDO_PID=$!
    trap 'kill "$SUDO_PID" 2>/dev/null' EXIT
}

# Homebrew runs `sudo --reset-timestamp` on every brew command, so the cached
# credential never survives one. Ask again, and only when it is really gone.
resudo() { sudo -n true 2>/dev/null || sudo -v; }

configure_git() {
    [ -n "$GIT_NAME" ] || return 0
    info "Git identity ($GIT_NAME <$GIT_EMAIL>)"
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global init.defaultBranch main
    git config --global pull.rebase true
    git config --global push.autoSetupRemote true

    # A separate identity for work repos, so a personal email can't leak into them
    if [ -n "$GIT_WORK_DIR" ] && [ -n "$GIT_WORK_EMAIL" ]; then
        local work="$HOME/.gitconfig-work" dir="${GIT_WORK_DIR%/}/"
        printf '[user]\n\temail = %s\n' "$GIT_WORK_EMAIL" >"$work"
        git config --global "includeIf.gitdir:$dir.path" "$work"
        echo "Repos under $dir will commit as <$GIT_WORK_EMAIL>"
    fi
}

# The repo is public, so ~/.secrets is created empty and never copied out of it.
# `secrets` (see .zshrc) unlocks it for an edit and re-locks it afterwards.
ensure_secrets() {
    [ -f "$HOME/.secrets" ] && return 0
    info "Creating ~/.secrets (read-only; edit it with: secrets)"
    printf '# Sourced by ~/.zshrc — API keys and tokens. Edit with: secrets\n' >"$HOME/.secrets"
    chmod 400 "$HOME/.secrets"
}

backup_existing() {
    local target="$1" new="$2" bak
    if [ -f "$target" ] && ! cmp -s "$new" "$target"; then
        bak="$target.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$target" "$bak"
        echo "Existing $(basename "$target") backed up to $bak"
    fi
}

install_oh_my_zsh() {
    info "Oh My Zsh + plugins"
    [ -d "$HOME/.oh-my-zsh" ] || RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}" plugin
    for plugin in zsh-syntax-highlighting zsh-autosuggestions; do
        [ -d "$custom/plugins/$plugin" ] || \
            git clone --depth 1 "https://github.com/zsh-users/$plugin.git" "$custom/plugins/$plugin"
    done
}

install_rust() {
    info "Rust (rustup)"
    have cargo || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    return 0
}

install_uv() {
    info "uv (python packages + interpreters) and ty (type checker)"
    have uv || curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    have ty || uv tool install ty
}

# Node, pnpm, Bun and Go come from mise, pinned by mise.toml, so every machine runs
# the same versions and a project can pin its own. Python stays with uv and Rust
# with rustup — mise's rust backend only drives rustup anyway.
install_runtimes() {
    if ! have mise; then
        echo "mise is not installed — no runtimes installed." >&2
        return 0
    fi
    info "Runtimes (mise: node, pnpm, bun, go)"
    MISE_YES=1 mise install
    # The rest of this script needs node: YouCompleteMe builds a JS completer.
    export PATH="$HOME/.local/share/mise/shims:$PATH"
}

install_claude() {
    info "Claude Code"
    have claude || curl -fsSL https://claude.ai/install.sh | bash
}

github_auth() {
    info "GitHub auth (gh handles SSH key generation & upload)"
    gh auth status >/dev/null 2>&1 || gh auth login --git-protocol ssh --web
}

install_dotfiles() {
    info "Dotfiles (.zshrc, .vimrc, zed, helix, mise, topgrade, .secrets)"
    mkdir -p "$HOME/.config/zed" "$HOME/.config/helix" "$HOME/.config/mise"
    local pair src dst
    for pair in "$1:$HOME/.zshrc" \
                ".vimrc:$HOME/.vimrc" \
                "topgrade.toml:$HOME/.config/topgrade.toml" \
                "mise.toml:$HOME/.config/mise/config.toml" \
                "zed_settings.json:$HOME/.config/zed/settings.json" \
                "zed_keymap.json:$HOME/.config/zed/keymap.json" \
                "helix_languages.toml:$HOME/.config/helix/languages.toml"; do
        src="$DOTFILES_DIR/${pair%%:*}" dst="${pair#*:}"
        backup_existing "$dst" "$src"
        cp "$src" "$dst"
    done
    ensure_secrets
}

setup_vim() {
    info "Vim plugins (Vundle) + YouCompleteMe"
    [ -d "$HOME/.vim/bundle/Vundle.vim" ] || \
        git clone --depth 1 https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim"
    vim -es -u "$HOME/.vimrc" +PluginInstall +qall </dev/null || true

    local ycm="$HOME/.vim/bundle/YouCompleteMe"
    if [ -d "$ycm" ] && ! ls "$ycm"/third_party/ycmd/ycm_core*.so >/dev/null 2>&1; then
        info "Compiling YCM (all completers: clangd, go, ts/js, java, c#, rust)"
        (cd "$ycm" && git submodule update --init --recursive && python3 install.py --all)
    fi
}

setup_neovim() {
    # Skipped when a config already exists — including Omarchy's LazyVim
    [ -d "$HOME/.config/nvim" ] && return 0
    info "Neovim config (kickstart.nvim: LSP, Telescope, Treesitter)"
    git clone https://github.com/nvim-lua/kickstart.nvim.git "$HOME/.config/nvim"
    nvim --headless "+Lazy! sync" +qa </dev/null || true
}

use_zsh() {
    info "Default shell -> zsh"
    if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
        resudo
        sudo chsh -s "$(command -v zsh)" "$USER"
    fi
}

gnome_tweaks() {
    have gsettings || return 0
    info "GNOME tweaks"
    gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' || true
    gsettings set org.gnome.shell.extensions.dash-to-dock show-trash true || true
    gsettings set org.gnome.Terminal.Legacy.Settings headerbar false || true
    return 0
}

# Language toolchains every platform gets. Must run before the per-distro CLI
# tool installs, which fall back to `cargo install`.
common_toolchains() {
    install_uv
    install_rust
}

# ~/Developer is the macOS convention (Finder gives it a special icon) and both
# .zshrc files put ~/Developer/bin on PATH, so keep the layout identical on Linux.
setup_dev_dir() {
    info "Development folder (~/Developer/bin)"
    mkdir -p "$HOME/Developer/bin"
}

# Everything else that is identical on every platform. $1 = which .zshrc to install.
common_stack() {
    setup_dev_dir
    configure_git
    install_claude
    install_oh_my_zsh
    install_dotfiles "$1"
    install_runtimes
    setup_vim
    setup_neovim
}

setup_macos() {
    # The GUI installer runs detached, so wait for it — brew needs a compiler.
    # This is the one step that can't be automated away; it is also the earliest.
    info "Xcode Command Line Tools"
    if ! xcode-select -p >/dev/null 2>&1; then
        xcode-select --install 2>/dev/null || true
        echo "Accept the Command Line Tools dialog — waiting for it to finish..."
        until xcode-select -p >/dev/null 2>&1; do sleep 10; done
    fi

    info "Homebrew"
    # NONINTERACTIVE, or the installer stops to ask for RETURN
    have brew || NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"

    info "Brew packages"
    brew install git gh macvim neovim helix btop thefuck fzf mise \
        llvm sqlite libpq poppler ripgrep fd \
        cmake mono openjdk \
        fastfetch lazydocker bat gitui yazi zellij \
        tealdeer tokei topgrade atuin pre-commit uv \
        awscli pipx macmon

    local prefix
    prefix="$(brew --prefix)"
    resudo
    sudo ln -sfn "$prefix/opt/openjdk/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk.jdk
    export PATH="$prefix/opt/openjdk/bin:$PATH"

    info "Casks (zed, iterm2, obsidian, helium, maccy)"
    install_cask zed Zed
    install_cask iterm2 iTerm
    install_cask obsidian Obsidian
    install_cask helium-browser Helium
    install_cask maccy Maccy
    [ -f "$HOME/.iterm2_shell_integration.zsh" ] || \
        curl -fsSL https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"
    if [ -f "$DOTFILES_DIR/iterm2.plist" ]; then
        defaults export com.googlecode.iterm2 "$HOME/.iterm2.plist.bak" 2>/dev/null || true
        defaults import com.googlecode.iterm2 "$DOTFILES_DIR/iterm2.plist"
    fi

    info "python tools (aws-mfa, virtualenvwrapper)"
    pipx install aws-mfa || true
    pipx install virtualenvwrapper || true

    info "macOS tweaks (fast Dock show, no recent apps in Dock)"
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0.4
    defaults write com.apple.dock show-recents -bool false
    killall Dock

    common_toolchains
    common_stack ".zshrc_arm64mac"
}

# Rust CLI tools: apt where the distro has them, cargo otherwise. "cmd:pkg", or
# "pkg" when the command and the package share a name.
debian_rust_tools() {
    info "Rust CLI tools (apt where available, cargo otherwise)"
    local t cmd pkg
    for t in tldr:tealdeer tokei atuin gitui zellij; do
        cmd="${t%%:*}" pkg="${t##*:}"
        have "$cmd" || apt_get install "$pkg" || cargo install --locked "$pkg"
    done
    have topgrade || cargo install --locked topgrade
    have yazi || cargo install --locked yazi-fm yazi-cli
    return 0
}

# Omarchy already has clipboard history: SUPER CTRL + V opens walker's clipboard
# module. A second watcher there would record every copy twice.
#
# Ringboard is Rust and covers both session types. Its own installer picks the
# X11 or the Wayland watcher, writes the systemd user units, and rewrites them
# for cargo's bin path — including the fallback for Wayland compositors without
# ext_data_control_manager_v1. Needs cargo, so call this after common_toolchains.
install_clipboard_history() {
    if is_omarchy; then
        echo "Omarchy supplies clipboard history (SUPER CTRL + V) — skipping Ringboard."
        return 0
    fi
    case "${XDG_SESSION_TYPE:-}" in
    x11 | wayland) ;;
    *) echo "No graphical session — skipping the clipboard manager." >&2; return 0 ;;
    esac
    have ringboard-server && return 0

    info "Clipboard history (Ringboard)"
    curl -sSfL https://raw.githubusercontent.com/SUPERCILEX/clipboard-history/master/install-with-cargo-systemd.sh |
        bash || echo "Ringboard install failed — see https://github.com/SUPERCILEX/clipboard-history" >&2
    return 0
}

# LACT's GUI talks to lactd over a socket, so the daemon has to be running
enable_lactd() {
    have lact || return 0
    info "LACT daemon"
    sudo systemctl enable --now lactd || true
}

setup_debian() {
    info "APT packages"
    apt_get update
    apt_get install zsh git curl wget gpg xclip vim-nox btop \
        build-essential cmake clang llvm libssl-dev libclang-dev libpq-dev \
        python3-dev python3-pip python3-setuptools pipx virtualenvwrapper \
        mono-complete default-jdk vlc dconf-editor ripgrep fd-find \
        xxd bat wl-clipboard xdg-utils pre-commit jq lsb-release
    apt_get install thefuck || pipx install thefuck
    apt_get install fastfetch || echo "fastfetch not in repos, skipping"
    # A cargo build of helix ships no runtime directory, so it has no grammars
    apt_get install helix || echo "helix not in repos, skipping"

    # Debian ships these under different binary names
    mkdir -p "$HOME/.local/bin"
    have fdfind && ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    have batcat && ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"

    info "GitHub CLI (official apt repo)"
    if ! have gh; then
        sudo mkdir -p -m 755 /etc/apt/keyrings
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt_get update && apt_get install gh
    fi

    # extrepo is Debian's own mechanism for third-party repositories and keeps
    # the key out of our hands. Not every release carries a mise recipe, so fall
    # back to mise's apt repository.
    info "mise (apt repo)"
    if ! have mise; then
        if apt_get install extrepo && sudo extrepo enable mise; then
            apt_get update
        else
            sudo install -dm 755 /etc/apt/keyrings
            curl -fsSL https://mise.jdx.dev/gpg-key.pub |
                sudo gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
            echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" |
                sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
            apt_get update
        fi
        apt_get install mise
    fi

    info "lazydocker (no apt package — official install script, lands in ~/.local/bin)"
    have lazydocker || curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

    info "Zed (official installer — lands in ~/.local)"
    have zed || curl -f https://zed.dev/install.sh | sh

    info "Ghostty (no official apt package — snap is the maintained route)"
    have ghostty || sudo snap install ghostty --classic || echo "ghostty: snap unavailable, install manually"

    info "Neovim (latest, official tarball — apt version is too old for kickstart)"
    if ! have nvim; then
        curl -fsSL -o /tmp/nvim.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
        sudo tar -C /opt -xzf /tmp/nvim.tar.gz && rm /tmp/nvim.tar.gz
        ln -sf /opt/nvim-linux-x86_64/bin/nvim "$HOME/.local/bin/nvim"
    fi

    info "fzf (latest, from git — apt version is too old for 'fzf --zsh')"
    if [ ! -d "$HOME/.fzf" ]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --bin
        ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
    fi

    info "Helium browser (official apt repo, so apt keeps it updated)"
    if [ ! -f /etc/apt/sources.list.d/helium.list ]; then
        sudo mkdir -p /usr/share/keyrings
        curl -fsSL https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc |
            sudo gpg --dearmor -o /usr/share/keyrings/helium.gpg
        echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" |
            sudo tee /etc/apt/sources.list.d/helium.list >/dev/null
        apt_get update
    fi
    apt_get install helium-bin

    # Obsidian and LACT publish no apt repo, and a hand-installed .deb never sees
    # an update. deb-get tracks their GitHub releases and installs real .debs
    # through dpkg — still apt, nothing sandboxed — and topgrade has a native
    # deb-get step, so `update` picks up new versions with no extra wiring.
    info "deb-get"
    if ! have deb-get; then
        curl -sL https://raw.githubusercontent.com/wimpysworld/deb-get/main/deb-get |
            sudo DEBIAN_FRONTEND=noninteractive bash -s install deb-get
    fi

    info "Obsidian + LACT (deb-get)"
    sudo DEBIAN_FRONTEND=noninteractive deb-get install obsidian lact

    enable_lactd

    info "nvtop on NVIDIA"
    has_nvidia && { have nvtop || apt_get install nvtop; }

    info "Docker (engine + compose plugin)"
    if ! have docker; then
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER"
    fi

    info "PostgreSQL (official pgdg repo)"
    if ! have psql; then
        apt_get install postgresql-common
        sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
        apt_get install postgresql
    fi

    gnome_tweaks
    common_toolchains
    install_clipboard_history
    debian_rust_tools
    common_stack ".zshrc_x86linux"
    use_zsh
}

# yay is preinstalled on Omarchy; paru ships with some CachyOS installs
arch_aur() {
    local helper
    for helper in yay paru; do
        have "$helper" && {
            "$helper" -S --needed --noconfirm \
                --answerclean None --answerdiff None --answeredit None "$@"
            return
        }
    done
    echo "No AUR helper (yay/paru) found — skipping: $*" >&2
    return 1
}

# `omarchy-update-perform` runs migrations and *then* `omarchy-hook post-update`,
# and migrations do re-add apps (cliamp and spotify both arrived that way), so
# re-apply the debloat from the hook. Delete
# ~/.config/omarchy/hooks/post-update.d/dotfiles-debloat to stop it.
install_debloat_hook() {
    have omarchy-hook-install || return 0
    info "Omarchy post-update hook (re-applies the debloat)"
    local dir
    dir="$(mktemp -d)"
    cat >"$dir/dotfiles-debloat" <<EOF
#!/bin/bash
# Installed by $DOTFILES_DIR/setup.sh
[ -x "$DOTFILES_DIR/omarchy-debloat.sh" ] && "$DOTFILES_DIR/omarchy-debloat.sh" --yes
EOF
    omarchy-hook-install post-update "$dir/dotfiles-debloat"
    rm -rf "$dir"
}

setup_arch() {
    local dgroups=()
    local pkgs=(
        zsh git curl wget xclip wl-clipboard xdg-utils vim neovim helix zed
        btop fastfetch base-devel cmake clang llvm openssl postgresql-libs
        python python-pip python-pipx
        mono jdk-openjdk mise
        github-cli fzf thefuck ripgrep fd ghostty
        lazydocker bat gitui yazi zellij tealdeer tokei atuin uv
        docker docker-compose postgresql pre-commit obsidian lact
    )
    has_nvidia && pkgs+=(nvtop)

    if is_omarchy; then
        info "Omarchy detected — keeping its Hyprland desktop, mpv/nautilus stack and yay"
        if ((DEBLOAT == 0)); then
            echo "Skipping the debloat pass (--no-debloat)."
        elif [ -x "$DOTFILES_DIR/omarchy-debloat.sh" ]; then
            case "$DEBLOAT_GROUPS" in
            skip) echo "Keeping Omarchy's preinstalled apps." ;;
            default) "$DOTFILES_DIR/omarchy-debloat.sh" --yes ;;
            all) "$DOTFILES_DIR/omarchy-debloat.sh" --yes --all ;;
            *)
                read -r -a dgroups <<<"$DEBLOAT_GROUPS"
                "$DOTFILES_DIR/omarchy-debloat.sh" --yes "${dgroups[@]}" ;;
            esac
            [ "$DEBLOAT_GROUPS" = skip ] || install_debloat_hook
        fi
    else
        # GNOME/X11-era extras that make no sense next to Hyprland
        pkgs+=(vlc dconf-editor)
    fi

    info "Pacman packages"
    sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"

    # python-virtualenvwrapper is AUR-only; pipx keeps it out of the pacman transaction
    info "virtualenvwrapper (pipx — not in the official repos)"
    pipx install virtualenvwrapper || true

    info "Helium browser (AUR)"
    have helium-browser || have helium || arch_aur helium-browser-bin

    enable_lactd

    info "Docker group"
    sudo usermod -aG docker "$USER"

    info "PostgreSQL init"
    sudo test -f /var/lib/postgres/data/PG_VERSION || sudo -u postgres initdb -D /var/lib/postgres/data

    is_omarchy || gnome_tweaks
    common_toolchains
    install_clipboard_history
    info "topgrade (AUR — not in the official repos)"
    have topgrade || arch_aur topgrade || cargo install --locked topgrade
    common_stack ".zshrc_x86linux"
    use_zsh
}

collect_inputs
sudo_keepalive

case "$(uname -s)" in
Darwin) setup_macos ;;
Linux)
    if have pacman; then setup_arch
    elif have apt-get; then setup_debian
    else echo "Unsupported Linux distro (no pacman/apt)" >&2; exit 1
    fi ;;
*) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

if have topgrade; then
    info "Upgrading existing packages (topgrade)"
    topgrade -y || true
fi

# Last, and the only thing that can block after the questions
[ "$AUTH_GH" = yes ] && github_auth

info "Done. Restart your terminal (or run: exec zsh)"
