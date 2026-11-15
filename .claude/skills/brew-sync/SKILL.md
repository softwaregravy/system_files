---
name: brew-sync
description: Check Homebrew's health with brew doctor, update the Brewfile to match currently installed Homebrew packages, show the diff, and optionally commit.
---

Check Homebrew's health, then sync the Brewfile with the current Homebrew state:

1. Run `brew doctor` and report only the warnings that need action, most urgent first. Skip its boilerplate ("these warnings are just used to help the Homebrew maintainers…"). Don't fix anything without asking.
   - **Outdated Command Line Tools or Xcode** ("too outdated"): report this first. Homebrew refuses every source build until it's fixed, and one refusal fails the whole upgrade batch. The CLT comes from `softwareupdate --list` / System Settings > Software Update and is never installed automatically. Xcode.app comes from the App Store, or can be deleted if it isn't used (`xcode-select -p` shows whether the CLT is the active toolchain).
   - **Kegs with no formulae** ("Deleted from homebrew/core"): the formula can never be installed again, so it has to come out of the Brewfile. Before uninstalling the keg, check that nothing links to it.
   - **Deprecated or disabled formulae and casks**: list them and the dates Homebrew gives, as candidates for replacement.
2. Run `zsh -ic update_brewfile` to regenerate `Brewfile` (no App Store apps, sorted) and `Brewfile.mas` (App Store apps only). Don't call `brew bundle dump` directly: without `--no-mas` it puts App Store apps back into the main Brewfile.
3. Run `git diff Brewfile Brewfile.mas` in `/Users/john/workspace/system_files` and show the output to the user.
4. Summarize what changed: list newly added packages and removed packages.
5. Ask the user if they want to commit the updated Brewfiles.
6. If yes: `git -C /Users/john/workspace/system_files add Brewfile Brewfile.mas && git -C /Users/john/workspace/system_files commit -m "Update Brewfile"`

Do not commit automatically without explicit user confirmation.
