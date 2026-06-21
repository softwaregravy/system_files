# User-Level Claude Instructions

These instructions apply across all projects on this machine.

## Dev Environment

This machine uses **mise** for version management (ruby, python, node) and **direnv** for per-project env activation. See `~/workspace/system_files` for full dotfiles setup.

## Ruby Project Setup

When starting work in a Ruby project for the first time, run:

```zsh
echo "PATH_add bin" >> .envrc && direnv allow .
```

This puts the project's `bin/` binstubs (`bin/rails`, `bin/rake`, `bin/rspec`, etc.) on PATH so you can run `rails`, `rake`, etc. without `bundle exec`.

If a gem lacks a binstub: `bundle binstubs <gemname>` once, then it's available directly.

**Why:** mise replaced RVM — mise reads `.ruby-version` and switches ruby automatically, but doesn't support RVM gemsets. direnv + `PATH_add bin` replicates the "no bundle exec" workflow.
