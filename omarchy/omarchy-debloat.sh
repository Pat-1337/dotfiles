#!/usr/bin/env bash

set -uo pipefail

DEFAULT_GROUPS=(apps webapps agents)
OPTIONAL_GROUPS=(gnome-apps input-method dotnet nvim)

DRY=0 YES=0
groups=()

info() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }
run()  { if ((DRY)); then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }
stamp="$(date +%Y%m%d-%H%M%S)"
backup() { run cp -a "$1" "$1.bak.$stamp"; }

usage() {
    cat <<EOF
Usage: ${0##*/} [--dry-run] [--yes] [--all] [group ...]

  --dry-run  print what would be removed, change nothing
  --yes      no confirmation prompt
  --all      default groups + every optional group

Default groups: ${DEFAULT_GROUPS[*]}
Optional      : ${OPTIONAL_GROUPS[*]}

  apps          1Password, Signal, Spotify, Typora, LibreOffice, OBS, Kdenlive,
                Pinta, Xournal++, LocalSend, Aether, cliamp, try
  webapps       Chromium web-app launchers (HEY, X, YouTube, ...) and the Hyprland
                bindings that point at them (swapped for Omarchy's plain-bindings)
  agents        npx stubs for the other coding agents (codex, gemini, copilot,
                opencode, playwright-cli, pi, ghui) — claude-code stays
  gnome-apps    evince, sushi, gnome-calculator, gnome-disk-utility
  input-method  fcitx5 (only needed for CJK/IME input)
  dotnet        dotnet-runtime-9.0
  nvim          omarchy-nvim (LazyVim); moves ~/.config/nvim aside so setup.sh
                can install kickstart.nvim instead
EOF
}

pkgs_for() {
    case "$1" in
    apps)         echo "1password-beta 1password-cli aether cliamp typora spotify libreoffice-fresh
                       xournalpp signal-desktop pinta obs-studio kdenlive localsend tobi-try" ;;
    gnome-apps)   echo "evince sushi gnome-calculator gnome-disk-utility" ;;
    input-method) echo "fcitx5 fcitx5-gtk fcitx5-qt" ;;
    dotnet)       echo "dotnet-runtime-9.0" ;;
    nvim)         echo "omarchy-nvim" ;;
    *)            echo "" ;;
    esac
}

stubs() {
    local dir="$HOME/.local/share/applications" f
    [ -d "$dir" ] || return 0
    for f in "$dir"/*.desktop; do
        [ -e "$f" ] && grep -qE "^Exec=.*($1)" "$f" && printf '%s\n' "$f"
    done
    return 0
}

WEBAPP_EXEC='omarchy-launch-webapp|omarchy-launch-or-focus-webapp|omarchy-webapp-handler'
AGENT_STUBS=(codex gemini copilot opencode playwright-cli pi ghui)

agent_stubs() {
    local s f
    for s in "${AGENT_STUBS[@]}"; do
        f="$HOME/.local/bin/$s"
        [ -f "$f" ] && grep -q 'mise where node@latest' "$f" && printf '%s\n' "$f"
    done
    return 0
}

remove_stubs() {
    local icons="$HOME/.local/share/applications/icons" f name
    while IFS= read -r f; do
        name="$(basename "$f" .desktop)"
        echo "  - $name"
        run rm -f "$f" "$icons/$name.png"
    done
}

plainify_bindings() {
    local lua="$HOME/.config/hypr/hyprland.lua" binds="$HOME/.config/hypr/bindings.lua"
    if [ -f "$lua" ]; then
        grep -q '^omarchy_preinstalled_bindings = false' "$lua" && return 0
        grep -q '^require("default.hypr.omarchy")' "$lua" || return 0
        info "Hyprland: preinstalled-app bindings off (backup: $lua.bak.$stamp)"
        backup "$lua"
        [ -f "$binds" ] && backup "$binds"
        run sed -i 's/^require("default.hypr.omarchy")/omarchy_preinstalled_bindings = false\n&/' "$lua"
        if ((DRY)); then
            echo "  [dry-run] append Tmux + Docker bindings to $binds"
        else
            cat >>"$binds" <<'BINDS'

-- Kept from Omarchy's preinstalled-app bindings (omarchy-debloat.sh)
o.bind("SUPER + ALT + RETURN", "Tmux", { omarchy = "terminal-tmux" })
o.bind("SUPER + SHIFT + D", "Docker", { tui = "omarchy-launch-docker-tui" })
BINDS
        fi
        [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null && run hyprctl reload
        return 0
    fi

    local src="${OMARCHY_PATH:-$HOME/.local/share/omarchy}/default/hypr/plain-bindings.conf"
    local dst="$HOME/.config/hypr/bindings.conf"
    [ -f "$src" ] && [ -f "$dst" ] || return 0
    grep -q 'omarchy-launch-webapp' "$dst" || return 0

    info "Hyprland bindings -> plain (backup: $dst.bak.$stamp)"
    backup "$dst"
    run cp "$src" "$dst"
    if ((DRY)); then
        echo "  [dry-run] re-append Tmux + Docker bindings"
    else
        cat >>"$dst" <<'BINDS'

# Kept from Omarchy's default bindings
bindd = SUPER ALT, RETURN, Tmux, exec, uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" bash -c "tmux attach || tmux new -s Work"
bindd = SUPER SHIFT, D, Docker, exec, omarchy-launch-tui lazydocker
BINDS
    fi
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null && run hyprctl reload
    return 0
}

while [ $# -gt 0 ]; do
    case "$1" in
    --dry-run) DRY=1 ;;
    --yes|-y)  YES=1 ;;
    --all)     groups=("${DEFAULT_GROUPS[@]}" "${OPTIONAL_GROUPS[@]}") ;;
    -h|--help) usage; exit 0 ;;
    -*)        usage; die "Unknown option: $1" ;;
    *)         groups+=("$1") ;;
    esac
    shift
done
[ ${#groups[@]} -gt 0 ] || groups=("${DEFAULT_GROUPS[@]}")

for g in "${groups[@]}"; do
    case " ${DEFAULT_GROUPS[*]} ${OPTIONAL_GROUPS[*]} " in
    *" $g "*) ;;
    *) usage; die "Unknown group: $g" ;;
    esac
done

[ "$(id -u)" -eq 0 ] && die "Run as your user, not root."
command -v pacman >/dev/null || die "Not an Arch system."
[ -d /usr/share/omarchy ] || [ -d "$HOME/.local/share/omarchy" ] || die "Omarchy not found."

remove=()
for g in "${groups[@]}"; do
    for pkg in $(pkgs_for "$g"); do
        pacman -Qq "$pkg" &>/dev/null && remove+=("$pkg")
    done
done

has_group() { case " ${groups[*]} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

echo "Groups: ${groups[*]}"
if [ ${#remove[@]} -gt 0 ]; then
    info "Packages to remove (${#remove[@]})"
    printf '  %s\n' "${remove[@]}"
fi
has_group webapps && { info "Web app launchers"; stubs "$WEBAPP_EXEC" | sed 's|.*/|  |;s|\.desktop$||'; }
has_group agents  && { info "Agent CLI stubs";   agent_stubs          | sed 's|.*/|  |'; }

if ((DRY == 0)) && ((YES == 0)); then
    printf '\nProceed? [y/N] '
    read -r reply
    [[ $reply == [yY]* ]] || die "Aborted."
fi

if [ ${#remove[@]} -gt 0 ]; then
    info "Removing packages"
    run sudo pacman -Rns --noconfirm "${remove[@]}"
fi

has_group webapps && { info "Removing web app launchers"; stubs "$WEBAPP_EXEC" | remove_stubs; plainify_bindings; }

if has_group agents; then
    info "Removing agent CLI stubs"
    while IFS= read -r f; do echo "  - ${f##*/}"; run rm -f "$f"; done < <(agent_stubs)
fi

if has_group nvim && [ -d "$HOME/.config/nvim" ]; then
    info "Moving Omarchy's LazyVim config aside"
    run mv "$HOME/.config/nvim" "$HOME/.config/nvim.omarchy.bak.$stamp"
fi

orphans=()
while IFS= read -r pkg; do orphans+=("$pkg"); done < <(pacman -Qtdq 2>/dev/null)
if [ ${#orphans[@]} -gt 0 ]; then
    info "Removing orphans"
    printf '  %s\n' "${orphans[@]}"
    run sudo pacman -Rns --noconfirm "${orphans[@]}"
fi

if command -v update-desktop-database >/dev/null; then
    run update-desktop-database "$HOME/.local/share/applications"
fi
command -v omarchy-restart-walker >/dev/null && run omarchy-restart-walker

info "Done."
echo "Kept on purpose: claude-code, lazydocker, obsidian, the TUI launchers,"
echo "the CUPS printing stack, and the Hyprland desktop."
