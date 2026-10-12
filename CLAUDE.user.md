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

## Task Queue (Todoist)

My to-dos live in Todoist, reached through the Todoist connector. When a to-do for me comes up in any session, don't leave it in the conversation: offer to file it, or file it when I wrap up.

- **Project:** Todoist projects are named with a rank number, lower first (for example `80 Clementine`). File the task in the project it belongs to; if none fits, use the Inbox.
- **Label:** exactly one per task, naming the scarcest thing it needs:
  - `quick`: under ten minutes on the phone
  - `block`: 20 to 40 focused minutes, phone is enough, anywhere
  - `desk`: needs the laptop
  - `call`: needs a person during business hours
  - `visit`: needs me there in person
  - `claude`: Claude can do the next step alone
  - `waiting`: blocked on someone else
- **Dates:** only real ones. The deadline is the real date (a renewal, an expiration, a due date); the date is when the task should start showing. No date otherwise.
- **Flag:** priority `p1` only when I say a task goes to the top.
- **Notes:** WHY, HOW, WATCH and REF, six lines at most, so I can act without rereading the session.
- **Code work stays in the repo:** issues, pull requests and handoff files. Only things I have to do by hand go to Todoist.

**Why:** I plan in sessions and then move on. A to-do left in the conversation is lost, and one with an invented date trains me to ignore dates.
