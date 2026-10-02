# Omarchy

## Detection

Omarchy used to be a git checkout in `~/.local/share/omarchy`. Now it is a
package in `/usr/share/omarchy`. `setup.sh`, `omarchy-debloat.sh`, and
`.zshrc_x86linux` accept either location.

## Package installs

Two things aborted the whole pacman transaction in earlier versions. Not one
package in the list was installed, zsh and nvtop included.

**The update guard.** Omarchy installs a pacman hook
(`omarchy-update-pacman-guard`) that aborts any direct `pacman -Syu`. System
upgrades must go through `omarchy update`, which takes a snapshot and runs the
keyring, migrations, and post-update hooks. So on Omarchy the script runs
`pacman -S --needed`, as `omarchy pkg add` does, against the databases from
the last `omarchy update` (Omarchy's snapshot mirror). If that fails, run
`omarchy update` and then the script again.

**Conflicts.** pacman asks before it removes a conflicting package,
`--noconfirm` answers no, and the transaction aborts. `pacman_conflict_free`
removes these from the list first:

- A package that is already provided under another name. For example,
  Omarchy's `mise-bin` provides `mise`. `pacman -Q mise` resolves provides
  too, so the check compares the name that pacman reports.
- A package that conflicts with an installed one. For example, `tealdeer`
  conflicts with Omarchy's `tldr`. `pacman -T` checks each conflict entry the
  way pacman does, provides included.

Each skipped package is printed.

## Debloat

`omarchy-debloat.sh` removes the preinstalled app layer. Omarchy's own
`omarchy-remove-preinstalls` also removes claude-code and lazydocker, which
this repository installs on purpose. This script keeps those and obsidian, plus
everything the Hyprland desktop needs (gum, impala, bluetui, wiremix,
nautilus, mpv, imv, gpu-screen-recorder), the Disk Usage and Docker TUI
launchers, and the CUPS printing stack.

```sh
./omarchy-debloat.sh --dry-run      # show, change nothing
./omarchy-debloat.sh                # default groups, asks first
./omarchy-debloat.sh --all --yes
./omarchy-debloat.sh dotnet nvim    # only these groups
```

Default groups:

- `apps`: 1Password, Signal, Spotify, Typora, LibreOffice, OBS Studio,
  Kdenlive, Pinta, Xournal++, LocalSend, Aether, cliamp, try.
- `webapps`: the Chromium web app launchers, and the Hyprland bindings that
  point at them.
- `agents`: the npx stubs for codex, gemini, copilot, opencode,
  playwright-cli, pi, ghui.

Optional groups: `gnome-apps`, `input-method` (fcitx5), `dotnet`, and `nvim`
(Omarchy's LazyVim). `--help` lists them all.

`pacman -Rns` gets only the packages that are installed, so one missing
package cannot abort the transaction. Orphans are removed afterwards.

- The agent stubs are removed only when they are npx wrappers written by
  `omarchy-npx-install`, never a binary you installed yourself.
- Keybindings: the removed apps still have keybindings. On current Omarchy
  (Lua config), the script sets `omarchy_preinstalled_bindings = false` in
  `~/.config/hypr/hyprland.lua` (backup: `hyprland.lua.bak`), and adds Tmux
  (SUPER ALT RETURN) and Docker (SUPER SHIFT D) back to `bindings.lua`. On
  older Omarchy, `bindings.conf` is replaced with Omarchy's
  `plain-bindings.conf` plus the same two bindings.
- Post-update hook: `omarchy update` runs migrations and then
  `omarchy-hook post-update`, and migrations can add apps back (cliamp and
  spotify arrived that way). So `setup.sh` installs
  `~/.config/omarchy/hooks/post-update.d/dotfiles-debloat`, which runs the
  debloat again. Delete that file to stop it.

> [!NOTE]
> [a-la-carchy](https://github.com/DanielCoffey1/a-la-carchy) is an
> interactive alternative. It is a large TUI that also sets the monitor layout,
> power profiles, and ASUS ROG fan curves. It suits a one-time manual setup.
> This script runs with no operator and can run again safely.

## Updates (topgrade)

On Omarchy, `setup.sh` installs a variant of `topgrade.toml`:

- The `system` step is disabled, because the update guard would abort its
  `pacman -Syu`.
- `omarchy-update -y` runs as a custom command. It updates pacman, AUR, mise,
  runs the migrations, and may ask for a reboot at the end. It is not a
  pre-command, because a failed pre-command stops topgrade, and the brew and
  mise steps would then not run.

## No snapshots

`omarchy update` runs `omarchy-snapshot create` before it upgrades, which
takes a Snapper snapshot of `/` (up to 5 are kept, and they appear in the
Limine boot menu). Snapper cannot be removed, because the `omarchy` package
depends on it. Deleting the `root` Snapper config does not last either: a
migration creates it again when it is missing.

`omarchy-update` treats exit code 127 from `omarchy-snapshot create` as
"Snapper is deliberately absent" and continues with no warning. So `setup.sh`
installs `/usr/local/bin/omarchy-snapshot`, which comes before `/usr/bin` on
`PATH`, and pacman never changes it:

- `create` exits 127, so no snapshot is taken.
- Anything else (`restore`) runs the real `/usr/bin/omarchy-snapshot`.

To take snapshots again, delete `/usr/local/bin/omarchy-snapshot`.

Delete the snapshots that already exist:

```sh
sudo snapper -c root --csvout list --columns number | tail -n +2 | grep -vx 0 |
  xargs -r sudo snapper -c root delete
```

## From bash to zsh

Omarchy configures bash through `~/.bashrc`, which reads
`$OMARCHY_PATH/default/bash`. `omarchy.zsh` gives zsh the same setup. It reads
Omarchy's files where zsh can, so Omarchy updates apply without changes here:

| Omarchy bash file | In zsh |
| --- | --- |
| `env-bootstrap`, `envs` | sourced as they are (POSIX) |
| `aliases` | sourced as it is (zsh-compatible) |
| `fns/*` | one zsh wrapper per function; each call runs the function in bash |
| `fns/worktrees` (`ga`, `gd`) | ported to zsh, because they change directory |
| `init` | zoxide, try (lazy); mise and fzf come from `~/.zshrc` |
| `shell`, `inputrc` | not used; Oh My Zsh covers history and completion |
| `completions` | a zsh `compdef` for the `omarchy` dispatcher |
| starship prompt | used instead of the Oh My Zsh theme |

Details:

- The `fns/*` wrappers exist because some of those functions use names that
  are special in zsh (`argv`, `columns`) and bash-only syntax (`read -p`).
  Running them in bash avoids porting each one.
- A zsh alias expands inside a function definition of the same name, so the
  Oh My Zsh git aliases `ga`, `gd`, `gcm`, `gcam` are removed before Omarchy's
  definitions load. Omarchy's meaning wins, as it did in bash.
- `EDITOR` stays `vim` (from `.zshrc`), and `SUDO_EDITOR` follows it.

### Your `~/.bashrc` lines

`setup.sh` copies your own `~/.bashrc` lines to `~/.zshrc.local`, which
`~/.zshrc` sources last. It leaves out:

- lines from Omarchy's template (`/usr/share/omarchy/default/bashrc`,
  `/etc/skel/.bashrc`)
- lines that `~/.zshrc` already does: cargo env, uv env, `brew shellenv`,
  mise, starship, zoxide, fzf, atuin
- bash-only commands: `shopt`, `bind`, `complete`, `set +h`

A line that is already in `~/.zshrc.local` is not added again, so the step can
run many times. `~/.bashrc` is not changed, so bash still works.

Omarchy installers such as `omarchy-install-dev-env` append to `~/.bashrc`
only. Run `setup.sh` again after one of them to carry the new line over, or
add it to `~/.zshrc.local` yourself.
