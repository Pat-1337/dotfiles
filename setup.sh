#!/usr/bin/env bash

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

apt_get() {
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y \
        -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef "$@"
}

install_cask() {
    [ -d "/Applications/$2.app" ] && return 0
    brew install --cask "$1"
}

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
is_omarchy() {
    [ -d /usr/share/omarchy ] || [ -d "$HOME/.local/share/omarchy" ] || have omarchy-update
}

has_nvidia() {
    have nvidia-smi && return 0
    [ -d /proc/driver/nvidia ] && return 0
    grep -qil 0x10de /sys/bus/pci/devices/*/vendor 2>/dev/null
}

if [ "$(id -u)" -eq 0 ]; then
    echo "Don't run setup.sh with sudo — run it as your user." >&2
    exit 1
fi

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
    DNS="${DNS:-ask}"

    if [ "$AUTH_GH" = ask ] && have gh && gh auth status >/dev/null 2>&1; then
        AUTH_GH=authed
    fi
    [ "$DNS" = ask ] && uses_cloudflare_dns && DNS=already

    if [ ! -t 0 ]; then
        info "Non-interactive — keeping the existing git identity and default groups"
        [ "$AUTH_GH" = ask ] && AUTH_GH=no
        [ "$DNS" = ask ] && DNS=keep
        return 0
    fi

    local ask_identity=0 ask_work=0 ask_debloat=0 ask_gh=0 ask_dns=0
    { [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; } || ask_identity=1

    if [ -n "$GIT_WORK_DIR" ]; then
        [ -z "$GIT_WORK_EMAIL" ] && ask_work=1
    elif ((ask_identity)) && ! has_git_work_identity; then
        ask_work=1
    fi

    is_omarchy && ((DEBLOAT)) && ask_debloat=1
    [ "$AUTH_GH" = ask ] && ask_gh=1
    [ "$DNS" = ask ] && ask_dns=1

    if ((ask_identity || ask_work || ask_debloat || ask_gh || ask_dns)); then
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

    if ((ask_dns)); then
        case "$(ask "Use Cloudflare DNS (1.1.1.1)? Breaks a company network's internal hostnames (y/n)" y)" in
        [yY]*) DNS=cloudflare ;;
        *) DNS=keep ;;
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
    case "$DNS" in
    already) echo "  dns            : already Cloudflare" ;;
    *) echo "  dns            : $DNS" ;;
    esac

    if ((ask_identity || ask_work || ask_debloat || ask_gh || ask_dns)); then
        read -r -p "
Press Enter to start, Ctrl-C to abort. " </dev/tty
    fi
}

sudo_keepalive() {
    [ "$(uname -s)" = Darwin ] && return 0
    info "Asking for sudo once"
    sudo -n true 2>/dev/null || sudo -v || exit 1
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
    SUDO_PID=$!
    trap 'kill "$SUDO_PID" 2>/dev/null' EXIT
}

resudo() { sudo -n true 2>/dev/null || sudo -v; }

CLOUDFLARE_DNS=(1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001)

mac_network_services() {
    networksetup -listnetworkserviceorder | awk '
        /^\(\*\)/ { name = "" }
        /^\([0-9]+\) / { name = $0; sub(/^\([0-9]+\) /, "", name) }
        /Device: [^)]/ && name != "" { print name; name = "" }'
}

uses_cloudflare_dns() {
    if [ "$(uname -s)" = Darwin ]; then
        local svc
        while IFS= read -r svc; do
            networksetup -getdnsservers "$svc" | grep -qx 1.1.1.1 || return 1
        done < <(mac_network_services)
        return 0
    fi
    { resolvectl dns 2>/dev/null; cat /etc/resolv.conf 2>/dev/null; } | grep -q '1\.1\.1\.1'
}

set_cloudflare_dns() {
    info "DNS: Cloudflare (${CLOUDFLARE_DNS[*]})"
    resudo
    if [ "$(uname -s)" = Darwin ]; then
        local svc was
        while IFS= read -r svc; do
            was="$(networksetup -getdnsservers "$svc" | grep -E '^[0-9a-f:.]+$' | tr '\n' ' ')"
            echo "  $svc (was: ${was:-automatic})"
            sudo networksetup -setdnsservers "$svc" "${CLOUDFLARE_DNS[@]}"
        done < <(mac_network_services)
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder 2>/dev/null || true
    elif have nmcli && [ "$(nmcli -t -f RUNNING general 2>/dev/null)" = running ]; then
        local con dev
        while IFS=: read -r con dev; do
            echo "  $con ($dev)"
            sudo nmcli connection modify "$con" \
                ipv4.dns "${CLOUDFLARE_DNS[0]} ${CLOUDFLARE_DNS[1]}" ipv4.ignore-auto-dns yes \
                ipv6.dns "${CLOUDFLARE_DNS[2]} ${CLOUDFLARE_DNS[3]}" ipv6.ignore-auto-dns yes
            sudo nmcli device reapply "$dev" >/dev/null || true
        done < <(nmcli -t -f NAME,DEVICE,TYPE connection show --active |
            awk -F: '$3 ~ /ethernet|wireless|wifi/ {print $1 ":" $2}')
    elif systemctl is-active --quiet systemd-resolved; then
        sudo mkdir -p /etc/systemd/resolved.conf.d
        printf '[Resolve]\nDNS=%s\nDomains=~.\n' "${CLOUDFLARE_DNS[*]}" |
            sudo tee /etc/systemd/resolved.conf.d/cloudflare.conf >/dev/null
        sudo systemctl restart systemd-resolved
    else
        echo "Neither NetworkManager nor systemd-resolved runs here, so DNS is unchanged." >&2
    fi
}

configure_git() {
    [ -n "$GIT_NAME" ] || return 0
    info "Git identity ($GIT_NAME <$GIT_EMAIL>)"
    git config --global user.name "$GIT_NAME"
    [ -n "$GIT_EMAIL" ] && git config --global user.email "$GIT_EMAIL"
    git config --global init.defaultBranch main
    git config --global pull.rebase true
    git config --global push.autoSetupRemote true

    if [ -n "$GIT_WORK_DIR" ] && [ -n "$GIT_WORK_EMAIL" ]; then
        local work="$HOME/.gitconfig-work" dir="${GIT_WORK_DIR%/}/"
        printf '[user]\n\temail = %s\n' "$GIT_WORK_EMAIL" >"$work"
        git config --global "includeIf.gitdir:$dir.path" "$work"
        echo "Repos under $dir will commit as <$GIT_WORK_EMAIL>"
    fi
}

ensure_secrets() {
    [ -f "$HOME/.secrets" ] && return 0
    info "Creating ~/.secrets (read-only; edit it with: secrets)"
    printf '# Sourced by ~/.zshrc — API keys and tokens. Edit with: secrets\n' >"$HOME/.secrets"
    chmod 400 "$HOME/.secrets"
}

backup_existing() {
    local target="$1" new="$2" base="${3:-$1}" bak
    if [ -f "$target" ] && ! cmp -s "$new" "$target"; then
        bak="$base.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$target" "$bak"
        echo "Existing $(basename "$base") backed up to $bak"
    fi
}

install_oh_my_zsh() {
    info "Oh My Zsh + plugins"
    local omz="$HOME/.oh-my-zsh" bak=""
    if ! have zsh; then
        echo "zsh is not installed — skipping Oh My Zsh." >&2
        return 0
    fi
    if [ -d "$omz" ] && [ ! -f "$omz/oh-my-zsh.sh" ]; then
        bak="$omz.incomplete.$(date +%Y%m%d-%H%M%S)"
        echo "Found an incomplete $omz — moving it to $bak"
        mv "$omz" "$bak"
    fi
    [ -d "$omz" ] || RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    [ -n "$bak" ] && [ -d "$bak/custom/plugins" ] && cp -an "$bak/custom/plugins/." "$omz/custom/plugins/"
    local custom="${ZSH_CUSTOM:-$omz/custom}" plugin
    for plugin in zsh-syntax-highlighting zsh-autosuggestions; do
        [ -d "$custom/plugins/$plugin" ] || \
            git clone --depth 1 "https://github.com/zsh-users/$plugin.git" "$custom/plugins/$plugin"
    done
}

install_rust() {
    info "Rust (rustup)"
    have cargo || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck source=/dev/null
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    have rustup && rustup component add rust-analyzer rust-src
    return 0
}

install_uv() {
    info "uv (python packages + interpreters) and ty (type checker)"
    have uv || curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    have ty || uv tool install ty
}

install_runtimes() {
    if ! have mise; then
        echo "mise is not installed — no runtimes installed." >&2
        return 0
    fi
    info "Runtimes (mise: node, pnpm, bun, go)"
    MISE_YES=1 mise install
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
    mkdir -p "$HOME/.config/zed" "$HOME/.config/helix" "$HOME/.config/mise/conf.d"
    release_mise_config
    local pair src dst topgrade="topgrade/topgrade.toml"
    is_omarchy && topgrade="$(omarchy_topgrade)"
    local -a pairs=("$1:$HOME/.zshrc" \
                "vim/vimrc:$HOME/.vimrc" \
                "$topgrade:$HOME/.config/topgrade.toml" \
                "mise/mise.toml:$HOME/.config/mise/conf.d/dotfiles.toml" \
                "zed/settings.json:$HOME/.config/zed/settings.json" \
                "zed/keymap.json:$HOME/.config/zed/keymap.json" \
                "helix/languages.toml:$HOME/.config/helix/languages.toml")
    if is_omarchy; then
        mkdir -p "$HOME/.config/zsh"
        pairs+=("zsh/omarchy.zsh:$HOME/.config/zsh/omarchy.zsh")
    fi
    for pair in "${pairs[@]}"; do
        src="${pair%%:*}" dst="${pair#*:}"
        [ "${src:0:1}" = / ] || src="$DOTFILES_DIR/$src"
        backup_existing "$dst" "$src"
        cp "$src" "$dst"
    done
    [ "$topgrade" = topgrade/topgrade.toml ] || rm -f "$topgrade"
    ensure_secrets
    migrate_bashrc
}

release_mise_config() {
    local cfg="$HOME/.config/mise/config.toml" old rev size
    [ -f "$cfg" ] || return 0
    old="$(mktemp)"
    for rev in $(git -C "$DOTFILES_DIR" rev-list HEAD -- mise/mise.toml mise.toml 2>/dev/null); do
        git -C "$DOTFILES_DIR" show "$rev:mise/mise.toml" >"$old" 2>/dev/null ||
            git -C "$DOTFILES_DIR" show "$rev:mise.toml" >"$old" 2>/dev/null || continue
        size="$(wc -c <"$old")"
        if ((size == 0)) || ! head -c "$size" "$cfg" | cmp -s - "$old"; then continue; fi
        echo "Moving this repo's runtimes out of $cfg into conf.d/dotfiles.toml"
        cp "$cfg" "$cfg.bak.$(date +%Y%m%d-%H%M%S)"
        { echo "[tools]"; tail -c +"$((size + 1))" "$cfg"; } >"$cfg.new"
        mv "$cfg.new" "$cfg"
        break
    done
    rm -f "$old"
}

omarchy_topgrade() {
    local cfg
    cfg="$(mktemp)"
    sed -e 's/^disable = \[\(.*\)\]/disable = [\1, "system"]/' \
        -e 's/^\[commands\]$/&\n"Omarchy" = "omarchy-update -y"/' "$DOTFILES_DIR/topgrade/topgrade.toml" >"$cfg"
    echo "$cfg"
}

migrate_bashrc() {
    local rc="$HOME/.bashrc" local_rc="$HOME/.zshrc.local" line added=0
    [ -f "$rc" ] || return 0
    local -a template=()
    local t
    for t in /usr/share/omarchy/default/bashrc /etc/skel/.bashrc; do
        [ -f "$t" ] && mapfile -t -O "${#template[@]}" template <"$t"
    done

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
        "" | "#"* | *"Custom commands after this line"*) continue ;;
        *".cargo/env"* | *'/bin/env"'* | *"brew shellenv"* | *"mise activate"* | \
            *"starship init"* | *"zoxide init"* | *"fzf --"* | *"atuin init"*) continue ;;
        shopt\ * | bind\ * | complete\ * | "set +h" | *bash_completion* | *"/bash/rc"* | *env-bootstrap*) continue ;;
        esac
        printf '%s\n' "${template[@]}" | grep -qxF -- "$line" && continue
        [ -f "$local_rc" ] && grep -qxF -- "$line" "$local_rc" && continue
        if ((added == 0)); then
            info "Carrying custom ~/.bashrc lines over to ~/.zshrc.local"
            [ -f "$local_rc" ] || printf '# Machine-local zsh config, sourced last by ~/.zshrc.\n' >"$local_rc"
            printf '\n# From ~/.bashrc (%s)\n' "$(date +%F)" >>"$local_rc"
        fi
        printf '%s\n' "$line" >>"$local_rc"
        echo "  $line"
        added=$((added + 1))
    done <"$rc"
    return 0
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
    if [ ! -d "$HOME/.config/nvim" ]; then
        info "Neovim config (kickstart.nvim: LSP, Telescope, Treesitter)"
        git clone https://github.com/nvim-lua/kickstart.nvim.git "$HOME/.config/nvim"
        nvim --headless "+Lazy! sync" +qa </dev/null || true
    fi
    mkdir -p "$HOME/.config/nvim/plugin"
    backup_existing "$HOME/.config/nvim/plugin/dotfiles.lua" "$DOTFILES_DIR/nvim/dotfiles.lua"
    cp "$DOTFILES_DIR/nvim/dotfiles.lua" "$HOME/.config/nvim/plugin/dotfiles.lua"
}

use_zsh() {
    info "Default shell -> zsh"
    local zsh current err
    zsh="$(command -v zsh)" || { echo "zsh is not installed — keeping the current shell." >&2; return 0; }
    current="$(getent passwd "$USER" | cut -d: -f7)"
    [ "$current" = "$zsh" ] && { echo "Already zsh."; return 0; }

    local term="${TERM:-xterm-256color}"
    [ "$term" = dumb ] && term=xterm-256color
    if ! err="$(TERM="$term" timeout 60 script -qec "$zsh -i -c exit" /dev/null 2>&1 </dev/null | tr -d '\r')" || [ -n "$err" ]; then
        echo "$HOME/.zshrc does not start cleanly — keeping $current. Output:" >&2
        echo "$err" >&2
        return 0
    fi
    grep -qxF "$zsh" /etc/shells || echo "$zsh" | sudo tee -a /etc/shells >/dev/null
    resudo
    sudo chsh -s "$zsh" "$USER" && echo "Login shell is now $zsh — log out and back in to use it everywhere."
}

gnome_tweaks() {
    have gsettings || return 0
    info "GNOME tweaks"
    gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' || true
    gsettings set org.gnome.shell.extensions.dash-to-dock show-trash true || true
    gsettings set org.gnome.Terminal.Legacy.Settings headerbar false || true
    return 0
}

common_toolchains() {
    install_uv
    install_rust
}

setup_dev_dir() {
    info "Development folder (~/Developer/bin)"
    mkdir -p "$HOME/Developer/bin"
}

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
    info "Xcode Command Line Tools"
    if ! xcode-select -p >/dev/null 2>&1; then
        xcode-select --install 2>/dev/null || true
        echo "Accept the Command Line Tools dialog — waiting for it to finish..."
        until xcode-select -p >/dev/null 2>&1; do sleep 10; done
    fi

    info "Homebrew"
    have brew || NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"

    info "Brew packages"
    brew install git gh macvim neovim helix btop thefuck fzf mise \
        llvm sqlite libpq poppler ripgrep fd \
        cmake mono openjdk \
        fastfetch lazydocker bat gitui yazi zellij \
        tealdeer tokei topgrade atuin pre-commit uv \
        awscli pipx macmon tree-sitter-cli

    local prefix jdk link
    prefix="$(brew --prefix)"
    jdk="$prefix/opt/openjdk/libexec/openjdk.jdk"
    link=/Library/Java/JavaVirtualMachines/openjdk.jdk
    if [ "$(readlink "$link" 2>/dev/null)" != "$jdk" ]; then
        info "Java symlink (needs root)"
        resudo
        sudo ln -sfn "$jdk" "$link"
    fi
    [ "$DNS" = cloudflare ] && set_cloudflare_dns
    export PATH="$prefix/opt/openjdk/bin:$PATH"

    info "Casks (zed, iterm2, obsidian, helium, maccy, Nerd Font symbols)"
    install_cask zed Zed
    install_cask iterm2 iTerm
    install_cask obsidian Obsidian
    install_cask helium-browser Helium
    install_cask maccy Maccy
    brew list --cask font-symbols-only-nerd-font >/dev/null 2>&1 || brew install --cask font-symbols-only-nerd-font
    [ -f "$HOME/.iterm2_shell_integration.zsh" ] || \
        curl -fsSL https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"
    if [ -f "$DOTFILES_DIR/iterm2/iterm2.plist" ]; then
        local live
        live="$(mktemp)"
        defaults export com.googlecode.iterm2 "$live" 2>/dev/null && plutil -convert xml1 "$live" &&
            backup_existing "$live" "$DOTFILES_DIR/iterm2/iterm2.plist" "$HOME/.iterm2.plist"
        rm -f "$live"
        defaults import com.googlecode.iterm2 "$DOTFILES_DIR/iterm2/iterm2.plist"
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
    common_stack "zsh/zshrc_arm64mac"
}

debian_rust_tools() {
    info "Rust CLI tools (apt where available, cargo otherwise)"
    local t cmd pkg
    for t in tldr:tealdeer tokei atuin gitui zellij; do
        cmd="${t%%:*}" pkg="${t##*:}"
        have "$cmd" || apt_get install "$pkg" || cargo install --locked "$pkg"
    done
    have topgrade || cargo install --locked topgrade
    have tree-sitter || cargo install --locked tree-sitter-cli
    have yazi || cargo install --locked yazi-fm yazi-cli
    return 0
}

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
        xxd bat wl-clipboard xdg-utils pre-commit jq lsb-release procps file fontconfig xz-utils
    apt_get install thefuck || pipx install thefuck
    apt_get install fastfetch || echo "fastfetch not in repos, skipping"
    apt_get install helix || echo "helix not in repos, skipping"

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

    info "Nerd Font symbols (no apt package — nvim icons)"
    local fonts="$HOME/.local/share/fonts/NerdFontsSymbolsOnly"
    if [ ! -f "$fonts/SymbolsNerdFontMono-Regular.ttf" ]; then
        mkdir -p "$fonts" &&
            curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz |
            tar -xJ -C "$fonts" && fc-cache -f "$fonts" >/dev/null
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
    install_colima
    common_stack "zsh/zshrc_x86linux"
    use_zsh
}

pacman_conflict_free() {
    local pkg conflict installed
    for pkg in "$@"; do
        installed="$(pacman -Qq "$pkg" 2>/dev/null)"
        if [ -n "$installed" ] && [ "$installed" != "$pkg" ]; then
            echo "Skipping $pkg: the installed $installed provides it" >&2
            continue
        fi
        if [ -z "$installed" ]; then
            for conflict in $(pacman -Si "$pkg" 2>/dev/null | sed -n 's/^Conflicts With *: //p'); do
                [ "$conflict" = None ] && continue
                if pacman -T "$conflict" >/dev/null 2>&1; then
                    echo "Skipping $pkg: it conflicts with the installed ${conflict%%[<>=]*}" >&2
                    continue 2
                fi
            done
        fi
        echo "$pkg"
    done
}

install_colima() {
    info "Homebrew on Linux + colima"
    local brew=/home/linuxbrew/.linuxbrew/bin/brew
    if [ ! -x "$brew" ]; then
        resudo
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
            { echo "Homebrew install failed — skipping colima." >&2; return 0; }
    fi
    "$brew" list --formula colima >/dev/null 2>&1 || "$brew" install colima ||
        echo "colima install failed — retry with: brew install colima" >&2
    return 0
}

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

disable_omarchy_snapshots() {
    have snapper || return 0
    info "Omarchy: no Snapper snapshots on update"
    sudo tee /usr/local/bin/omarchy-snapshot >/dev/null <<'EOF'
#!/bin/bash
[ "${1:-}" = create ] && exit 127
exec /usr/bin/omarchy-snapshot "$@"
EOF
    sudo chmod 755 /usr/local/bin/omarchy-snapshot
}

install_debloat_hook() {
    have omarchy-hook-install || return 0
    info "Omarchy post-update hook (re-applies the debloat)"
    local dir
    dir="$(mktemp -d)"
    cat >"$dir/dotfiles-debloat" <<EOF
#!/bin/bash
# Installed by $DOTFILES_DIR/setup.sh
[ -x "$DOTFILES_DIR/omarchy/omarchy-debloat.sh" ] && "$DOTFILES_DIR/omarchy/omarchy-debloat.sh" --yes
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
        lazydocker bat gitui yazi zellij tealdeer tokei atuin uv tree-sitter-cli ttf-nerd-fonts-symbols-mono
        docker docker-compose postgresql pre-commit obsidian lact
    )
    has_nvidia && pkgs+=(nvtop)

    if is_omarchy; then
        info "Omarchy detected — keeping its Hyprland desktop, mpv/nautilus stack and yay"
        if ((DEBLOAT == 0)); then
            echo "Skipping the debloat pass (--no-debloat)."
        elif [ -x "$DOTFILES_DIR/omarchy/omarchy-debloat.sh" ]; then
            case "$DEBLOAT_GROUPS" in
            skip) echo "Keeping Omarchy's preinstalled apps." ;;
            default) "$DOTFILES_DIR/omarchy/omarchy-debloat.sh" --yes ;;
            all) "$DOTFILES_DIR/omarchy/omarchy-debloat.sh" --yes --all ;;
            *)
                read -r -a dgroups <<<"$DEBLOAT_GROUPS"
                "$DOTFILES_DIR/omarchy/omarchy-debloat.sh" --yes "${dgroups[@]}" ;;
            esac
            [ "$DEBLOAT_GROUPS" = skip ] || install_debloat_hook
        fi
        disable_omarchy_snapshots
    else
        pkgs+=(vlc dconf-editor)
    fi

    info "Pacman packages"
    mapfile -t pkgs < <(pacman_conflict_free "${pkgs[@]}")
    if is_omarchy; then
        sudo pacman -S --needed --noconfirm "${pkgs[@]}" ||
            echo "pacman failed — run 'omarchy update', then this script again." >&2
    else
        sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"
    fi

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
    install_colima
    common_stack "zsh/zshrc_x86linux"
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

[ "$(uname -s)" = Linux ] && [ "$DNS" = cloudflare ] && set_cloudflare_dns

if have topgrade; then
    info "Upgrading existing packages (topgrade)"
    [ "$(uname -s)" = Darwin ] || resudo
    topgrade -y || true
fi

[ "$AUTH_GH" = yes ] && github_auth

info "Done. Restart your terminal (or run: exec zsh)"
