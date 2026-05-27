# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal macOS dotfiles and system configuration for a developer machine. All config files are **symlinked** from this repo to the home directory by `setup.sh` — edits here are immediately live (no copy/sync step needed).

## Applying Changes by Type

| Change type | How it takes effect |
|---|---|
| `zshrc`, `zshrc.cmdprompt`, `vimrc`, `gitconfig`, `screenrc`, etc. | Immediately via symlink; `source ~/.zshrc` to reload in the current shell session |
| `Brewfile` — add or remove packages | Run `brew bundle --file=Brewfile` after editing; `brew bundle cleanup` to uninstall removed packages |
| `setup.sh` Vim plugin list (`VIM_PACKAGES` array) | Run `setup.sh` again, or manually: `git clone <url> ~/.vim/pack/vendor/start/<name>` |
| `git_hooks/prepare-commit-msg` | Immediately via symlink at `~/.git-hooks/` |

## Key Conventions

- **pnpm over npm**: `npm` is aliased to warn and redirect. Use `p` (alias) or `pnpm` directly. Never suggest `npm install`.
- **Brewfile sync**: The `update_brewfile()` function (in `zshrc`) dumps current Homebrew state to Brewfile. Run it to capture new installs before committing. Or use the `/brew-sync` skill.
- **API keys**: Loaded at shell startup from `~/.keys/` (not in this repo — gitignored). Key name templates are in `keys/`. Never commit real keys.
- **Vim plugins**: Managed in the `VIM_PACKAGES` array in `setup.sh`. Plugins are cloned to `~/.vim/pack/vendor/start/<name>` during setup. Use the `/add-vim-plugin` skill to add new ones.
- **Global git hooks**: Configured via `gitconfig` (`hooksPath = ~/.git-hooks`). The `prepare-commit-msg` hook uses `OPENAI_API_KEY` (from `~/.keys/openai`) to auto-generate conventional commit messages.

## setup.sh

Full machine bootstrap — creates all symlinks, installs Homebrew packages, sets up pyenv/RVM/fnm, and clones Vim plugins. Re-running is safe (idempotent for most steps). Requires interactive terminal (prompts for some decisions).

## Version Managers

- **Python**: pyenv (auto-detects highest installed Python 3.x)
- **Ruby**: RVM — lazy-loaded when a `.ruby-version` file is detected in the current directory
- **Node**: fnm — auto-switches on `cd` if `.node-version` is present
