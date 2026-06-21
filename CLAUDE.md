# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal macOS dotfiles and system configuration for a developer machine. All config files are **symlinked** from this repo to the home directory by `setup.sh` — edits here are immediately live (no copy/sync step needed).

## Applying Changes by Type

| Change type | How it takes effect |
|---|---|
| `zshrc`, `vimrc`, `gitconfig`, `starship.toml`, `tmux.conf`, `screenrc`, etc. | Immediately via symlink; `source ~/.zshrc` to reload in the current shell session |
| `Brewfile` — add or remove packages | Run `brew bundle --file=Brewfile` after editing; `brew bundle cleanup` to uninstall removed packages |
| `setup.sh` Vim plugin list (`VIM_PACKAGES` array) | Run `setup.sh` again, or manually: `git clone <url> ~/.vim/pack/vendor/start/<name>` |
| `git_hooks/prepare-commit-msg` | Immediately via symlink at `~/.git-hooks/` |
| `claude/settings.json`, `claude/statusline-command.sh`, `CLAUDE.user.md` | Immediately via symlink into `~/.claude/`; restart Claude Code to pick up `settings.json` changes |

## Key Conventions

- **pnpm over npm**: `npm` is aliased to warn and redirect. Use `p` (alias) or `pnpm` directly. Never suggest `npm install`.
- **Brewfile sync**: The `update_brewfile()` function (in `zshrc`) dumps current Homebrew state to Brewfile. Run it to capture new installs before committing. Or use the `/brew-sync` skill.
- **API keys**: Loaded at shell startup from `~/.keys/` (not in this repo — gitignored). Key name templates are in `keys/`. Never commit real keys.
- **Vim plugins**: Managed in the `VIM_PACKAGES` array in `setup.sh`. Plugins are cloned to `~/.vim/pack/vendor/start/<name>` during setup. Use the `/add-vim-plugin` skill to add new ones.
- **Global git hooks**: Configured via `gitconfig` (`hooksPath = ~/.git-hooks`). The `prepare-commit-msg` hook uses `OPENAI_API_KEY` (from `~/.keys/openai`) to auto-generate conventional commit messages.
- **Claude config**: Only the portable config files are checked in (`claude/settings.json`, `claude/statusline-command.sh`, `CLAUDE.user.md`), symlinked individually into `~/.claude/`. Do **not** symlink the whole `~/.claude/` directory — it also holds conversation transcripts (`projects/`), `history.jsonl`, plugins, caches, and credentials, none of which belong in a published repo. Machine-local overrides go in `~/.claude/settings.local.json` (untracked).

## setup.sh

Full machine bootstrap — creates all symlinks, installs Homebrew packages, sets up language runtimes via mise, and clones Vim plugins. Re-running is safe (idempotent for most steps). Requires interactive terminal (prompts for some decisions).

## Version Managers

- **mise** is the single runtime manager for Ruby, Python, and Node (replaced pyenv, RVM, and fnm). Activated in `zshrc` via `mise activate zsh`; auto-switches on `.ruby-version` / `.python-version` / `.node-version`. Global defaults are pinned in `setup.sh` with `mise use -g ruby@latest python@latest node@lts` (`@latest` = newest stable, not nightly).
- **direnv** activates per-project env on `cd` (`direnv hook zsh`). The `PATH_add bin` pattern puts a Ruby project's binstubs on PATH so `rails`/`rake`/`rspec` run without `bundle exec` — see `CLAUDE.user.md`.
- **Prompt**: `starship` (`starship.toml`), which replaced the old hand-rolled `zshrc.cmdprompt`.
