---
name: add-vim-plugin
description: Add a new Vim plugin to this dotfiles repo so it installs on all machines via setup.sh. Trigger with /add-vim-plugin <github-url-or-user/repo>.
disable-model-invocation: true
---

The user wants to add a Vim plugin. The plugin is specified as $ARGUMENTS (GitHub URL or "user/repo" shorthand).

Steps:

1. **Normalize the URL**: if $ARGUMENTS is "user/repo" format, expand to `https://github.com/user/repo.git`. If it already ends in `.git`, use as-is. Otherwise append `.git`.

2. **Derive the plugin name**: take the last path segment and strip `.git` (e.g. `vim-fugitive`).

3. **Check for duplicates**: read `setup.sh` and confirm the URL is not already in `VIM_PACKAGES`.

4. **Edit setup.sh**: add the URL to the `VIM_PACKAGES` array, just before the `# Add more packages here` comment line.

5. **Show the diff** and ask the user to confirm before writing.

6. **Clone locally** so it works immediately (don't wait for the next full setup.sh run):
   ```
   git clone <url> ~/.vim/pack/vendor/start/<plugin-name>
   ```
   Show the command and ask the user if they want Claude to run it.

7. **Commit**: suggest `git add setup.sh && git commit -m "Add vim plugin: <plugin-name>"` and ask if they want it committed now.
