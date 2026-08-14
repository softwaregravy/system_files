# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal macOS dotfiles and system configuration for a developer machine. All config files are **symlinked** from this repo to the home directory by `setup.sh` — edits here are immediately live (no copy/sync step needed).

## Applying Changes by Type

| Change type | How it takes effect |
|---|---|
| `zshrc`, `vimrc`, `gitconfig`, `starship.toml`, `tmux.conf`, `screenrc`, etc. | Immediately via symlink; `source ~/.zshrc` to reload in the current shell session |
| `Brewfile` — add or remove packages | Run `brew bundle --file=Brewfile` after editing; `brew bundle cleanup --no-mas` to uninstall removed packages (`--no-mas` so it ignores App Store apps, which live in `Brewfile.mas`) |
| `Brewfile.mas` — Mac App Store apps | Installed by `setup.sh` (interactive — App Store requires sign-in/authorization, can't run unattended). Routine `brew bundle` against the main `Brewfile` never touches these |
| `setup.sh` Vim plugin list (`VIM_PACKAGES` array) | Run `setup.sh` again, or manually: `git clone <url> ~/.vim/pack/vendor/start/<name>` |
| `git_hooks/prepare-commit-msg` | Immediately via symlink at `~/.git-hooks/` |
| `claude/settings.json`, `claude/statusline-command.sh`, `CLAUDE.user.md` | Immediately via symlink into `~/.claude/`; restart Claude Code to pick up `settings.json` changes |
| `iterm2/com.googlecode.iterm2.plist` | Not symlinked — iTerm2 reads/writes this file directly (Preferences > General > "Load preferences from a custom folder or URL", wired up by `setup.sh`). Edit via the iTerm2 GUI as normal; changes autosave into this file, then `git diff`/commit it. **Quit iTerm2 first** before hand-editing this file or running `defaults write com.googlecode.iterm2 ...` — iTerm2 holds the whole domain in memory and overwrites the file wholesale on its next save/quit |

## Key Conventions

- **pnpm over npm**: `npm` is aliased to warn and redirect. Use `p` (alias) or `pnpm` directly. Never suggest `npm install`.
- **Brewfile sync**: The `update_brewfile()` function (in `zshrc`) dumps current Homebrew state to two files — `Brewfile` (taps/brews/casks/vscode, dumped with `--no-mas`) and `Brewfile.mas` (Mac App Store apps only). Run it to capture new installs before committing. Or use the `/brew-sync` skill. The split exists because App Store (`mas`) installs require interactive authorization and would otherwise break the non-interactive `brew bundle` flow.
- **API keys**: Loaded at shell startup from `~/.keys/` (not in this repo — gitignored). Key name templates are in `keys/`. Never commit real keys.
- **Vim plugins**: Managed in the `VIM_PACKAGES` array in `setup.sh`. Plugins are cloned to `~/.vim/pack/vendor/start/<name>` during setup. Use the `/add-vim-plugin` skill to add new ones.
- **Global git hooks**: Configured via `gitconfig` (`hooksPath = ~/.git-hooks`). The `prepare-commit-msg` hook uses `OPENAI_API_KEY` (from `~/.keys/openai`) to auto-generate conventional commit messages.
- **Claude config**: Only the portable config files are checked in (`claude/settings.json`, `claude/statusline-command.sh`, `CLAUDE.user.md`), symlinked individually into `~/.claude/`. Do **not** symlink the whole `~/.claude/` directory — it also holds conversation transcripts (`projects/`), `history.jsonl`, plugins, caches, and credentials, none of which belong in a published repo. Machine-local overrides go in `~/.claude/settings.local.json` (untracked).
- **iTerm2 config**: Profiles, keybindings, hotkey-window bindings, and color schemes live in `iterm2/com.googlecode.iterm2.plist`, loaded via iTerm2's own "custom preferences folder" feature rather than a symlink. `setup.sh` points iTerm2 at that folder (skipped if iTerm2 is currently running, since it caches prefs in memory). To edit: quit iTerm2 if it's running, make the change, relaunch — never edit the plist while iTerm2 is open.

## setup.sh

Full machine bootstrap — creates all symlinks, installs Homebrew packages, sets up language runtimes via mise, and clones Vim plugins. Re-running is safe (idempotent for most steps). Requires interactive terminal (prompts for some decisions).

## Version Managers

- **mise** is the single runtime manager for Ruby, Python, and Node (replaced pyenv, RVM, and fnm). Activated in `zshrc` via `mise activate zsh`; auto-switches on `.ruby-version` / `.python-version` / `.node-version`. Global defaults are pinned in `setup.sh` with `mise use -g ruby@latest python@latest node@lts` (`@latest` = newest stable, not nightly).
- **direnv** activates per-project env on `cd` (`direnv hook zsh`). The `PATH_add bin` pattern puts a Ruby project's binstubs on PATH so `rails`/`rake`/`rspec` run without `bundle exec` — see `CLAUDE.user.md`.
- **Prompt**: `starship` (`starship.toml`), which replaced the old hand-rolled `zshrc.cmdprompt`.
