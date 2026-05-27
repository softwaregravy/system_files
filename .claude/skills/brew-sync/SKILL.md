---
name: brew-sync
description: Update the Brewfile to match currently installed Homebrew packages, show the diff, and optionally commit.
---

Sync the Brewfile with the current Homebrew state:

1. Run `brew bundle dump --force --file=/Users/john/workspace/system_files/Brewfile` to overwrite the Brewfile with currently installed packages and casks. (This is equivalent to the `update_brewfile()` function in zshrc.)
2. Run `git diff Brewfile` in `/Users/john/workspace/system_files` and show the output to the user.
3. Summarize what changed: list newly added packages and removed packages.
4. Ask the user if they want to commit the updated Brewfile.
5. If yes: `git -C /Users/john/workspace/system_files add Brewfile && git -C /Users/john/workspace/system_files commit -m "Update Brewfile"`

Do not commit automatically without explicit user confirmation.
