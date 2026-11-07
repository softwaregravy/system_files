# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal macOS dotfiles and system configuration for a developer machine. All config files are **symlinked** from this repo to the home directory by `setup.sh` — edits here are immediately live (no copy/sync step needed).

There is also an **Ubuntu port** for headless servers, driven by `setup-ubuntu.sh` + `aptfile-ubuntu`. It is strictly additive: files that needed changing have a `-ubuntu` sibling, and the macOS originals are never modified. See "Ubuntu Port" below before touching anything with a `-ubuntu` suffix.

## Applying Changes by Type

| Change type | How it takes effect |
|---|---|
| `zshrc`, `vimrc`, `gitconfig`, `starship.toml`, `tmux.conf`, `screenrc`, etc. | Immediately via symlink; `source ~/.zshrc` to reload in the current shell session |
| `Brewfile` — add or remove packages | Run `brew bundle --file=Brewfile` after editing; `brew bundle cleanup --no-mas` to uninstall removed packages (`--no-mas` so it ignores App Store apps, which live in `Brewfile.mas`) |
| `Brewfile.mas` — Mac App Store apps | Installed by `setup.sh` (interactive — App Store requires sign-in/authorization, can't run unattended). Routine `brew bundle` against the main `Brewfile` never touches these |
| `setup.sh` Vim plugin list (`VIM_PACKAGES` array) | Run `setup.sh` again, or manually: `git clone <url> ~/.vim/pack/vendor/start/<name>` |
| `git_hooks/prepare-commit-msg` | Immediately via symlink at `~/.git-hooks/` |
| `claude/settings.json`, `claude/statusline-command.sh`, `CLAUDE.user.md` | Immediately via symlink into `~/.claude/`; restart Claude Code to pick up `settings.json` changes |
| `claude/ccstatusline.json` | Immediately via symlink at `~/.config/ccstatusline/settings.json` — the status line's widget config. Edit it with the TUI (`npx ccstatusline@latest`), which writes back **through** the symlink into this repo, then `git diff`/commit. Hand-editing the JSON works too. Shared with Ubuntu unchanged — only the invocation differs, see the Ubuntu table |
| `*-ubuntu` files (`zshrc-ubuntu`, `vimrc-ubuntu`, …) | Immediately via symlink on an Ubuntu box; `source ~/.zshrc` to reload. **macOS never reads these.** |
| `aptfile-ubuntu` — add or remove packages | Run `./setup-ubuntu.sh` again (it re-runs apt), or just `sudo apt install <pkg>`. Removal is manual — there is no `brew bundle cleanup` equivalent |
| `iterm2/com.googlecode.iterm2.plist` | Not symlinked — iTerm2 reads/writes this file directly (Preferences > General > "Load preferences from a custom folder or URL", wired up by `setup.sh`). Edit via the iTerm2 GUI as normal; changes autosave into this file, then `git diff`/commit it. **Quit iTerm2 first** before hand-editing this file or running `defaults write com.googlecode.iterm2 ...` — iTerm2 holds the whole domain in memory and overwrites the file wholesale on its next save/quit |

## Key Conventions

- **pnpm over npm**: `npm` is aliased to warn and redirect. Use `p` (alias) or `pnpm` directly. Never suggest `npm install`.
- **Brewfile sync**: The `update_brewfile()` function (in `zshrc`) dumps current Homebrew state to two files — `Brewfile` (taps/brews/casks/vscode, dumped with `--no-mas`) and `Brewfile.mas` (Mac App Store apps only). Run it to capture new installs before committing. Or use the `/brew-sync` skill. The split exists because App Store (`mas`) installs require interactive authorization and would otherwise break the non-interactive `brew bundle` flow.
- **API keys**: Loaded at shell startup from `~/.keys/` (not in this repo — gitignored). Key name templates are in `keys/`. Never commit real keys.
- **Vim plugins**: Managed in the `VIM_PACKAGES` array in `setup.sh`. Plugins are cloned to `~/.vim/pack/vendor/start/<name>` during setup. Use the `/add-vim-plugin` skill to add new ones.
- **Global git hooks**: Configured via `gitconfig` (`hooksPath = ~/.git-hooks`). The `prepare-commit-msg` hook uses `OPENAI_API_KEY` (from `~/.keys/openai`) to auto-generate conventional commit messages.
- **Claude status line**: `settings.json` points `statusLine` at [ccstatusline](https://github.com/sirmalloc/ccstatusline) (`npx -y ccstatusline@latest`), which renders model / git branch / context % / session cost / 5-hour block timer. Its widget config is `claude/ccstatusline.json`, symlinked to `~/.config/ccstatusline/settings.json`. The TUI resolves symlinks before saving (writes a temp file in the *target's* directory, then renames onto it), so TUI edits land in this repo — that's why `*.tmp` is gitignored. Two things to know: the config carries a `version` field and ccstatusline **refuses a config newer than the installed version** (older ones auto-migrate), so pin the version via the TUI's "Pinned global install" if you sync across machines — that also drops the ~0.7s `npx` startup paid on every refresh. The TUI's Export Config writes this same file plus an `exportedBy` key, so an export is drop-in usable as the settings file; version-controlling this file replaces the need for export/import. `claude/statusline-command.sh` is the previous hand-rolled status line — no longer referenced by `settings.json`, kept as a fallback. Ubuntu runs the same status line off the same `ccstatusline.json`, but invokes it as `mise exec node@lts -- npx -y ccstatusline@latest`: on the server `node` lives behind mise, which only reaches `PATH` via `mise activate` (interactive shells only), so a bare `npx` resolves to nothing in the systemd-launched `claude-rc@` remote-control session and the bar comes up blank. `mise` itself is at `/usr/bin/mise`, on the default `PATH`, so wrapping works everywhere. That wrapper costs an extra process per refresh, so the server uses `refreshInterval: 30` against macOS's `10`.
- **Claude config**: Only the portable config files are checked in (`claude/settings.json`, `claude/statusline-command.sh`, `claude/ccstatusline.json`, `CLAUDE.user.md`), symlinked individually into `~/.claude/` (and `~/.config/`). Do **not** symlink the whole `~/.claude/` directory — it also holds conversation transcripts (`projects/`), `history.jsonl`, plugins, caches, and credentials, none of which belong in a published repo. Machine-local overrides go in `~/.claude/settings.local.json` (untracked) — that includes auto mode's `autoMode.environment` block, which `/auto-mode-setup` writes into `~/.claude/settings.json` by default and which therefore has to be moved out by hand, since that path is a symlink into this public repo.
- **iTerm2 config**: Profiles, keybindings, hotkey-window bindings, and color schemes live in `iterm2/com.googlecode.iterm2.plist`, loaded via iTerm2's own "custom preferences folder" feature rather than a symlink. `setup.sh` points iTerm2 at that folder (skipped if iTerm2 is currently running, since it caches prefs in memory). To edit: quit iTerm2 if it's running, make the change, relaunch — never edit the plist while iTerm2 is open.

## Ubuntu Port

Tested on Ubuntu 24.04 "noble", x86_64, headless. Entrypoint is `setup-ubuntu.sh` (`setup.sh` now refuses to run on non-Darwin and points at it).

**Rule: never edit a macOS file to make Ubuntu work.** If a config needs to differ, add or update the `-ubuntu` sibling. If a change is portable, make it in *both* files and say so in the commit.

| Ubuntu-only file | Notes |
|---|---|
| `setup-ubuntu.sh` | apt instead of Homebrew. Phases are individually fail-soft; only "not Linux", "running as root", "repo missing", "sudo failed" and "zsh/git/curl absent after apt" abort the run |
| `aptfile-ubuntu` | The `Brewfile` analogue. One package per line, `#` comments. Names are filtered through `apt-cache show` before install so one bad name can't sink the batch |
| `zshrc-ubuntu` | GNU vs BSD commands (`ls --color=auto`, `top -o %CPU`, `date +%s`, basename-only `--exclude-dir`); no `/opt/homebrew` or `/Applications` on PATH; every `eval "$(x init …)"` is guarded with `command -v` because this file is the login shell; tmux auto-attach on SSH |
| `vimrc-ubuntu` | Headless vim has no `+clipboard`, so copy goes over **OSC 52** via the `vim-oscyank` plugin. Vim 9.1 in noble has no native OSC 52 and never will (LTS doesn't rebase vim) |
| `tmux.conf-ubuntu` | `pbcopy` → OSC 52. `set -g set-clipboard on` is load-bearing: tmux only forwards an application's OSC 52 when the value is exactly `on`, not `external` |
| `gitconfig-ubuntu` | Identical minus `core.hooksPath` — the AI `prepare-commit-msg` hook is deliberately not installed on the server |
| `claude/settings-ubuntu.json` | Status line is `mise exec node@lts -- npx …` instead of a bare `npx` (mise-managed node is not on the systemd `PATH`) and refreshes every 30s instead of 10; plus `autoUpdatesChannel`. The widget config `claude/ccstatusline.json` itself is shared unchanged |
| `bin/newrc`, `systemd/claude-rc@.service` | Linux-only. `newrc <name> [git-url]` creates a project under `~/workspaces/claude-rc-projects/` and enables a `claude remote-control` systemd user unit for it |
| `CHEATSHEET-ubuntu.md` | Ubuntu deltas to `CHEATSHEET.md` |

Not ported: `Brewfile`, `Brewfile.mas`, `iterm2/`, `iTerm2 State.itermexport`, `git_hooks/prepare-commit-msg`, `init.vim` (vestigial — `setup.sh` never linked it).

**Path convention differs:** macOS uses `~/workspace/system_files` (singular), the Ubuntu box uses `~/workspaces/system_files` (**plural**). `zshrc-ubuntu` sets `SYSTEM_FILES_DIR` accordingly.

**Never run `git lfs install` on the server** — `~/.gitconfig` is a symlink into this repo, so it would dirty the working tree. The lfs filter is already in `gitconfig-ubuntu`.

**Not available via apt**, installed separately by `setup-ubuntu.sh`: `mise` and `ngrok` (official signed apt repos), `starship` (`install.sh` into `~/.local/bin`), `zsh-fast-syntax-highlighting` (git clone into `~/.zsh`), `pnpm` (corepack, after mise installs node).

## setup.sh

Full machine bootstrap — creates all symlinks, installs Homebrew packages, sets up language runtimes via mise, and clones Vim plugins. Re-running is safe (idempotent for most steps). Requires interactive terminal (prompts for some decisions).

## Version Managers

- **mise** is the single runtime manager for Ruby, Python, and Node (replaced pyenv, RVM, and fnm). Activated in `zshrc` via `mise activate zsh`; auto-switches on `.ruby-version` / `.python-version` / `.node-version`. Global defaults are pinned in `setup.sh` with `mise use -g ruby@latest python@latest node@lts` (`@latest` = newest stable, not nightly).
- **direnv** activates per-project env on `cd` (`direnv hook zsh`). The `PATH_add bin` pattern puts a Ruby project's binstubs on PATH so `rails`/`rake`/`rspec` run without `bundle exec` — see `CLAUDE.user.md`.
- **Prompt**: `starship` (`starship.toml`), which replaced the old hand-rolled `zshrc.cmdprompt`.
