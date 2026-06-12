#!/usr/bin/env bash

### Dotfiles setup — macOS (arm64), Debian/Ubuntu, Arch/CachyOS

set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVM_VERSION="v0.40.5"

info() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

install_oh_my_zsh() {
    info "Oh My Zsh + plugins"
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]    || git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
}

install_rust() {
    info "Rust (rustup)"
    command -v cargo >/dev/null || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

install_node() {
    info "Node (nvm $NVM_VERSION)"
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
    fi
    export NVM_DIR="$HOME/.nvm"
    . "$NVM_DIR/nvm.sh"
    command -v node >/dev/null || nvm install --lts
}

github_auth() {
    info "GitHub auth (gh handles SSH key generation & upload)"
    gh auth status >/dev/null 2>&1 || gh auth login --git-protocol ssh --web
}

install_dotfiles() {
    local zshrc_src="$1"
    info "Dotfiles (.zshrc, .vimrc, .secrets)"
    cp "$DOTFILES_DIR/$zshrc_src" "$HOME/.zshrc"
    cp "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
    if [ -f "$DOTFILES_DIR/.secrets" ]; then
        cp "$DOTFILES_DIR/.secrets" "$HOME/.secrets"
        chmod 600 "$HOME/.secrets"
    else
        echo "NOTE: $DOTFILES_DIR/.secrets not found — copy it to ~/.secrets manually (it is gitignored)."
    fi
}

setup_vim() {
    info "Vim plugins (Vundle) + YouCompleteMe"
    [ -d "$HOME/.vim/bundle/Vundle.vim" ] || git clone --depth 1 https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim"
    vim -es -u "$HOME/.vimrc" +PluginInstall +qall || true

    local ycm="$HOME/.vim/bundle/YouCompleteMe"
    if [ -d "$ycm" ] && ! ls "$ycm"/third_party/ycmd/ycm_core*.so >/dev/null 2>&1; then
        info "Compiling YCM (all completers: clangd, go, ts/js, java, c#, rust)"
        (cd "$ycm" && git submodule update --init --recursive && python3 install.py --all)
    fi
}

setup_neovim() {
    info "Neovim config (kickstart.nvim: LSP, Telescope, Treesitter)"
    if [ ! -d "$HOME/.config/nvim" ]; then
        git clone https://github.com/nvim-lua/kickstart.nvim.git "$HOME/.config/nvim"
        nvim --headless "+Lazy! sync" +qa || true
    fi
}

use_zsh() {
    info "Default shell -> zsh"
    [ "$(basename "${SHELL:-}")" = "zsh" ] || chsh -s "$(command -v zsh)"
}

gnome_tweaks() {
    command -v gsettings >/dev/null || return 0
    info "GNOME tweaks"
    gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' || true
    gsettings set org.gnome.shell.extensions.dash-to-dock show-trash true || true
    gsettings set org.gnome.Terminal.Legacy.Settings headerbar false || true
}

setup_macos() {
    info "Xcode Command Line Tools"
    xcode-select -p >/dev/null 2>&1 || xcode-select --install

    info "Homebrew"
    if ! command -v brew >/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"

    info "Brew packages"
    brew install git gh macvim neovim btop thefuck fzf pyenv pyenv-virtualenv \
        pygments llvm sqlite libpq poppler ripgrep fd \
        cmake go node mono openjdk

    sudo ln -sfn "$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk.jdk
    export PATH="$(brew --prefix)/opt/openjdk/bin:$PATH"

    info "iTerm2 + shell integration"
    brew install --cask iterm2
    [ -f "$HOME/.iterm2_shell_integration.zsh" ] || curl -fsSL https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh"

    info "Bun"
    command -v bun >/dev/null || curl -fsSL https://bun.sh/install | bash

    info "AWS + python tools (awscli, aws-mfa, virtualenvwrapper)"
    brew install awscli pipx
    pipx install aws-mfa || true
    pipx install virtualenvwrapper || true

    info "macOS tweaks (fast Dock show)"
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0.4
    killall Dock

    install_rust
    install_oh_my_zsh
    github_auth
    install_dotfiles ".zshrc_arm64mac"
    setup_vim
    setup_neovim
}

setup_debian() {
    info "APT packages"
    sudo apt-get update
    sudo apt-get install -y zsh git curl wget gpg xclip vim-nox btop \
        build-essential cmake clang llvm libssl-dev libclang-dev libpq-dev \
        python3-dev python3-pip python3-setuptools pipx virtualenvwrapper \
        mono-complete golang default-jdk vlc dconf-editor ripgrep fd-find
    sudo apt-get install -y thefuck || pipx install thefuck
    sudo apt-get install -y fastfetch || echo "fastfetch not in repos, skipping"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"

    info "GitHub CLI (official apt repo)"
    if ! command -v gh >/dev/null; then
        sudo mkdir -p -m 755 /etc/apt/keyrings
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update && sudo apt-get install -y gh
    fi

    info "Neovim (latest, official tarball — apt version is too old for kickstart)"
    if ! command -v nvim >/dev/null; then
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

    info "Docker (engine + compose plugin)"
    if ! command -v docker >/dev/null; then
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER"
    fi

    info "PostgreSQL (official pgdg repo)"
    if ! command -v psql >/dev/null; then
        sudo apt-get install -y postgresql-common
        sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
        sudo apt-get install -y postgresql
    fi

    gnome_tweaks
    install_rust
    install_node
    install_oh_my_zsh
    github_auth
    install_dotfiles ".zshrc_x86linux"
    setup_vim
    setup_neovim
    use_zsh
}

setup_arch() {
    info "Pacman packages"
    sudo pacman -Syu --needed --noconfirm zsh git curl wget xclip vim neovim \
        btop fastfetch base-devel cmake clang llvm openssl postgresql-libs \
        python python-pip python-pipx python-virtualenvwrapper \
        mono go jdk-openjdk vlc dconf-editor \
        github-cli fzf thefuck ripgrep fd \
        docker docker-compose postgresql

    info "Docker group"
    sudo usermod -aG docker "$USER"

    info "PostgreSQL init"
    if ! sudo test -f /var/lib/postgres/data/PG_VERSION; then
        sudo -u postgres initdb -D /var/lib/postgres/data
    fi

    gnome_tweaks
    install_rust
    install_node
    install_oh_my_zsh
    github_auth
    install_dotfiles ".zshrc_x86linux"
    setup_vim
    setup_neovim
    use_zsh
}

case "$(uname -s)" in
    Darwin) setup_macos ;;
    Linux)
        if command -v pacman >/dev/null; then setup_arch
        elif command -v apt-get >/dev/null; then setup_debian
        else echo "Unsupported Linux distro (no pacman/apt)" >&2; exit 1
        fi ;;
    *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

info "Done. Restart your terminal (or run: exec zsh)"
