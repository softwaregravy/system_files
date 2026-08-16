


this is my setup for terminals.  Primarily OS X; there is also an Ubuntu port
for headless servers — see "Quick Setup for a New Ubuntu Server" below.

The color scheme is based off of ir_black from infinitered
http://blog.infinitered.com
which links to a git repository

I also liked a lot of his dotfiles, and so use those too
http://github.com/twerth/dotfiles

The command line is pretty much Phil!'s
http://aperiodic.net/phil/prompt/
with some slight modifications for os x


# Quick Setup for New Mac

To set up a new Mac with your system configuration, run this command in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/softwaregravy/system_files/main/setup.sh | bash
```

```bash
# Or to inspect before running Download the script
curl -fsSL https://raw.githubusercontent.com/softwaregravy/system_files/main/setup.sh -o setup.sh

# Review the contents
less setup.sh

# Make executable and run
chmod +x setup.sh
./setup.sh
```

# Quick Setup for a New Ubuntu Server

`setup.sh` is macOS-only (Homebrew, `xcode-select`, `defaults`, mas). On Ubuntu
use `setup-ubuntu.sh`, which does the same job with apt. Tested on Ubuntu 24.04
"noble", x86_64, headless.

```bash
git clone https://github.com/softwaregravy/system_files.git ~/workspaces/system_files
cd ~/workspaces/system_files

# Run it from a detached tmux/screen session — it takes ~10 minutes and a
# mid-dpkg kill leaves apt half-configured.
tmux new -s setup
./setup-ubuntu.sh
```

Flags: `--yes` (never prompt), `--skip-apt` (symlinks only), `--no-chsh` (don't
change the login shell), `--help`.

## How the Ubuntu port is organised

Config files that are already portable are symlinked straight from this repo and
shared with the Mac. Files that needed real changes have a `-ubuntu` sibling; the
macOS original is never modified.

| Ubuntu file | Why it differs from the macOS original |
|---|---|
| `zshrc-ubuntu` | No Homebrew; GNU instead of BSD `ls`/`top`/`date`/`grep`; Linux paths; guarded `eval`s; tmux auto-attach on SSH |
| `vimrc-ubuntu` | OSC 52 clipboard (headless vim has no `+clipboard`) via the vim-oscyank plugin |
| `tmux.conf-ubuntu` | Copy goes over OSC 52 instead of `pbcopy` |
| `gitconfig-ubuntu` | No `core.hooksPath` — the AI `prepare-commit-msg` hook is not installed here |
| `claude/settings-ubuntu.json` | `$HOME`-relative statusline path; keeps `autoUpdatesChannel` |
| `aptfile-ubuntu` | The `Brewfile` equivalent — one apt package per line |
| `bin/newrc`, `systemd/claude-rc@.service` | Linux-only; spin up a `claude remote-control` session under systemd |

Shared unchanged: `screenrc`, `inputrc`, `irbrc`, `gemrc`, `npmrc`,
`starship.toml`, `ir_black.vim`, `vim/after/syntax/sh.vim`, `CLAUDE.user.md`,
`claude/statusline-command.sh`, `ngrok.yml` (linked to `~/.config/ngrok/` rather
than `~/Library/Application Support/`).

## Clipboard over SSH

Copying in tmux or vim on the server reaches your local macOS clipboard via OSC
52 escape sequences. Enable it once in iTerm2:

**Settings → General → Selection → "Applications in terminal may access clipboard"**

Then `y` in tmux copy-mode and `vv` in vim both land in your Mac's pasteboard.

## Notes

- Four things have no apt package and are installed separately by the script:
  **mise** and **ngrok** (official signed apt repos), **starship** (`install.sh`
  into `~/.local/bin`), **fast-syntax-highlighting** (git clone into `~/.zsh`).
  **pnpm** comes from corepack once mise has installed node.
- `bat` and `fd-find` install as `batcat`/`fdfind` on Debian/Ubuntu because of
  filename clashes; the script symlinks them to `bat`/`fd` in `~/.local/bin`.
- `gh` comes from Ubuntu universe (2.45.0), which trails upstream by a fair way.
  If you need newer, add GitHub's own apt repo.
- Runtimes come from mise (`node@lts`, `python@latest`, `ruby@latest`). mise
  prefers precompiled builds; the `-dev` packages in `aptfile-ubuntu` are there
  for the source-compile fallback.
- Anything the script replaces in `$HOME` is moved to
  `~/.dotfiles-backup/<timestamp>/`, along with the full run log.
- See `CHEATSHEET-ubuntu.md` for the Ubuntu-specific keybindings and differences.





