# Runtimes and updates

## Who owns what

| Runtime | Tool |
| --- | --- |
| Node, pnpm, Bun, Go | mise (`mise.toml`) |
| Python and Python packages | uv (plus `ty`) |
| Rust | rustup |
| Java, mono | system packages |

- Python is not in mise, because uv owns it.
- Rust is not in mise, because mise's Rust backend only drives rustup.
- Java and mono stay system packages, because the macOS JVM symlink and the
  YouCompleteMe Java completer both build against them.
- pnpm is its own mise tool. corepack and `npm -g` both install pnpm into the
  node install, so the next node upgrade deletes it.

## mise config files

- `mise.toml` goes to `~/.config/mise/conf.d/dotfiles.toml`.
- `~/.config/mise/config.toml` belongs to the machine. Omarchy keeps its tools
  there (codex, gh, cursor-agent, ...), and `mise use -g` writes to it.
  `config.toml` overrides `conf.d`, so a pin there beats this repository.
- `/etc/mise/conf.d/omarchy.toml` holds Omarchy's system-wide settings.
- `[settings]` in `mise.toml`: `vcpkg` is disabled, because it came in through
  brew without `VCPKG_ROOT` and asks for sudo.

Older versions of `setup.sh` copied `mise.toml` over `config.toml`.
`release_mise_config` compares `config.toml` with every committed version of
`mise.toml`. If `config.toml` starts with one of them, that part is removed.
Anything added after it is kept, and the old file is backed up.

## Updates

`update` is an alias for `topgrade`. `topgrade.toml`:

- `assume_yes` and `no_retry`: no prompts, so it can run unattended.
- The built-in `mise` step is disabled. It runs `mise self-update` first,
  which fails when a package manager installed mise ("mise is installed via a
  package manager, cannot update"). The step then stops before it upgrades
  any tools. Instead, a custom command runs `mise upgrade --yes`. The package
  manager (pacman, apt, brew) updates mise itself.
- On Omarchy, the `system` step is replaced by `omarchy-update -y`. See
  [omarchy.md](omarchy.md).
