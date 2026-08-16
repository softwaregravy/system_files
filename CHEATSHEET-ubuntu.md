# Ubuntu Workflow Cheatsheet

Deltas from `CHEATSHEET.md` for the headless Ubuntu server. Everything in the
main cheatsheet still applies — tmux prefix is `Ctrl-a`, Vim leader is `,` —
this file only covers what is *different* when you're SSHed into the box.

---

## Clipboard — the big one

There is no `pbcopy` and no X server here. Copying travels to your Mac as an
**OSC 52 escape sequence**, which tmux emits and iTerm2 turns into a real
pasteboard write.

**One-time setup on the Mac:**
iTerm2 → Settings → General → **Selection** tab →
☑ *"Applications in terminal may access clipboard"*

Without that checkbox everything below silently does nothing.

| Where | Key | Result |
|---|---|---|
| tmux copy-mode | `y` or `Enter` after a selection | ⌘V on the Mac pastes it |
| tmux, mouse | drag-select in a pane | ⌘V pastes it (stays in copy mode) |
| Vim | `vv` (or `3vv`) | ⌘V pastes those lines |
| Vim | `,y` + motion, `,yy`, or `,y` in visual mode | ⌘V pastes the motion/selection |
| Vim | `yy` | buffer register only — **not** the Mac clipboard |

Notes:
- `vv` also leaves the text in Vim's unnamed register, so `p` still works locally.
- Anything OSC-52-copied inside tmux also becomes a tmux paste buffer, so
  `C-a P` pastes it into another pane.
- **GNU screen swallows OSC 52** — `screen-256color` has no `Ms` capability.
  Use tmux when you want to copy out. `screenrc` is still symlinked for muscle
  memory.
- Option-drag in iTerm2 still bypasses mouse reporting for a plain local
  selection — useful across panes or inside a pager.

---

## Auto-attach on SSH

SSHing in drops you straight into a tmux session named `main` (attaching if it
already exists). Detaching with `C-a d` ends the SSH session.

To get in **without** tmux:

```bash
ssh ghost -t /bin/bash     # skips zsh entirely — also the recovery path
NO_TMUX=1 ssh ghost        # only works if sshd has AcceptEnv NO_TMUX
```

The auto-attach never fires for non-interactive shells, `ssh host <cmd>`,
scp/rsync/sftp, panes already inside tmux, or Claude Code's Bash tool.

---

## `newrc` — Claude Code remote-control sessions

Linux-only. Creates a project directory, marks it trusted in `~/.claude.json`,
and enables a systemd user unit that runs `claude remote-control` in a detached
tmux server.

```bash
newrc myproject                              # empty directory
newrc myproject git@github.com:me/repo.git   # clone first

systemctl --user status  claude-rc@myproject
systemctl --user restart claude-rc@myproject
systemctl --user disable --now claude-rc@myproject

tmux -L cc-myproject attach                  # look inside the session
```

Projects live in `~/workspaces/claude-rc-projects/<name>`. Lingering is enabled,
so the units survive logout.

---

## Command differences from macOS

| macOS | Ubuntu | Why |
|---|---|---|
| `bat` | `bat` (via a shim) | Debian ships it as `batcat`; `~/.local/bin/bat` symlinks it |
| `fd` | `fd` (via a shim) | Debian ships it as `fdfind`; same treatment |
| `brew install x` | `sudo apt install x` | add it to `aptfile-ubuntu` to make it permanent |
| `brew bundle` | `./setup-ubuntu.sh` | re-runs apt against `aptfile-ubuntu` |
| `update_brewfile` | *(gone)* | no Homebrew here |
| `pbcopy` / `pbpaste` | *(gone)* | see Clipboard above |
| `open .` | *(gone)* | headless |

`ls`, `top`, `date`, and `grep --exclude-dir` are GNU here. The aliases already
account for it — `ls` is `--color=auto`, `top` is `-o %CPU`.

---

## Runtimes

`mise` manages ruby, python and node; `direnv` handles per-project env.

```bash
mise ls                    # what's installed
mise use -g node@22        # change the global default
mise use node@20           # pin for this project (writes .mise.toml)
```

`.ruby-version` / `.node-version` / `.python-version` files are honoured.

**Don't `pip install` into the system python** — Ubuntu 24.04 is PEP 668
externally-managed and will refuse. Use a mise-managed python, a venv (`ae` /
`de`), or `pipx` for CLI tools.

For Ruby projects, the `PATH_add bin` direnv trick from `CLAUDE.user.md` works
the same way here.

---

## Things that are intentionally absent

- **AI commit messages.** `core.hooksPath` is not set in `gitconfig-ubuntu`, so
  `git commit` opens a plain editor. To enable it: add `hooksPath = ~/.git-hooks`
  to `gitconfig-ubuntu`, then symlink `git_hooks/prepare-commit-msg` into
  `~/.git-hooks/` and put a real key in `~/.keys/openai`.
- **Neovim.** `init.vim` is in the repo but has never been linked by either
  setup script.
- **Everything GUI** — iTerm2 prefs, casks, Mac App Store apps.

---

## Recovery

```bash
ssh ghost -t /bin/bash        # get a shell if zsh is broken
chsh -s /bin/bash             # put the login shell back

ls ~/.dotfiles-backup/        # every file setup-ubuntu.sh replaced, per run
cat ~/.dotfiles-backup/<timestamp>/setup.log
```
