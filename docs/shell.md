# Shell (.zshrc)

## PATH

- `typeset -U path` keeps `PATH` free of duplicates, so sourcing `~/.zshrc`
  again is safe.
- `~/Developer/bin`, `~/.cargo/bin`, and `~/.local/bin` come first.
- pnpm keeps its global binaries in `$PNPM_HOME/bin`, outside the node
  install, so they survive node upgrades.
- Linux, Homebrew: `brew shellenv` puts brew first. Homebrew brings its own
  `llvm`, `python`, and `systemd` as colima dependencies, and they would
  shadow the distro's copies. So `zsh/zshrc_x86linux` moves the brew directories
  to the end of `PATH`. mise activates after that, so its tools come first.
- macOS: the compiler search paths (`LIBRARY_PATH`, `CPATH`, ...) are tied to
  arrays. That prevents duplicates and an empty entry from a trailing colon,
  which a compiler reads as the current directory. The `brew shellenv` values
  are set directly, without the subprocess, and the brew completions are added
  before `compinit`. The gem bin directory for each Ruby version is added,
  because brew leaves it off `PATH`.

## Oh My Zsh

- `oh-my-zsh.sh` is sourced only if it exists, so a half-finished install
  still gives a working shell.
- The `virtualenvwrapper` plugin loads only when `virtualenvwrapper.sh` is on
  `PATH`. Without it, the plugin prints an error at every prompt.
- On Omarchy, starship replaces the theme. See [omarchy.md](omarchy.md).

## Tools

- `thefuck` starts a Python interpreter, so `fuck` loads its alias on the
  first call instead of at every shell start.
- `dprune` removes images, containers, and networks, but keeps volumes,
  because database data lives there. Add `--volumes` to remove them too.
- `0x0 <file>` uploads a file to 0x0.st.
- Linux `pbcopy` and `pbpaste` use `wl-copy` on Wayland and `xclip` on X11.
  They keep no history.

## Secrets

`~/.secrets` holds API keys and tokens, and has mode 400. `~/.zshrc` sources
it with `allexport`, so a line without `export` still reaches child processes.

`secrets` edits it:

1. It sets mode 600.
2. It opens `$EDITOR`.
3. An `always` block sets mode 400 again, even if the editor fails.
4. It reads the new values into the current shell.

A GUI editor returns at once, which would lock the file again during the
edit. So `secrets` adds `-f` for `mvim`/`gvim` and `--wait` for
`zed`/`code`/`subl`.

## ~/.zshrc.local

Sourced last, on both platforms. It is for settings that belong to one machine
and stay out of this repository. On Linux, `setup.sh` also puts your custom
`~/.bashrc` lines there. See [omarchy.md](omarchy.md).
