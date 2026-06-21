# Workflow Cheatsheet

Muscle-memory reference for the **tmux** (was screen) + **Vim/NERDTree** + **starship** workflow.

Notation: `C-a` = press Ctrl+a, release, then press the next key. tmux prefix is
`Ctrl-a` (kept from screen on purpose). Vim leader is `,` (comma).

---

## tmux (replaces screen)

### Sessions — when you `cd` into a project
| Action | Command | Screen equivalent |
|---|---|---|
| Start a named session | `tmux new -s myproj` | `screen -S myproj` |
| Re-attach later | `tmux a -t myproj` | `screen -r` |
| List sessions | `tmux ls` | `screen -ls` |
| Detach (leave running) | `C-a d` | `C-a d` |

### Windows (your old "several screen windows")
| Action | Key | Screen equivalent |
|---|---|---|
| New window | `C-a c` (or `C-a C-c`) | same |
| Next / prev window | `C-a n` / `C-a p` | same |
| Jump to window # | `C-a 0`…`9` | same |
| Rename window | `C-a ,` | `C-a A` |
| List / pick windows | `C-a w` | `C-a "` |
| Close window | `C-a &` (or `exit`) | `C-a k` |

### Panes — the upgrade over screen
| Action | Key |
|---|---|
| Split vertical (side-by-side) | `C-a %` |
| Split horizontal (stacked) | `C-a "` |
| Move between panes | `C-a` + arrow key, or `C-a o` |
| Zoom pane fullscreen (toggle) | `C-a z` |
| Close pane | `C-a x` |

### Copy / paste / mouse
| Action | Key |
|---|---|
| Copy mode / scrollback | `C-a [`, then vi keys; `y` copies to macOS clipboard |
| Paste tmux buffer | `C-a P` (or Cmd+V from iTerm) |
| Mouse | on — click panes/windows, drag borders to resize, scroll to enter copy mode |

> Hold **⌥ Option** while dragging in iTerm2 for native selection that bypasses tmux.

---

## Vim

The "side menu" is **NERDTree**.

| Action | Key |
|---|---|
| **Toggle NERDTree side menu** | `,n` |
| Open file from tree | `Enter` (or single-click — mouse mode on) |
| Previous file | `,p` |
| Comment toggle | `,c` |
| Toggle line numbers | `,s` |
| Toggle invisibles | `,i` |
| Escape (insert → normal) | `jj` |

### Splits
| Action | Key |
|---|---|
| New vertical split | `,v` |
| New horizontal split | `,h` |
| Move between **vim** splits | `Ctrl-h/j/k/l` |

### Insert-mode shortcuts
| Type | Inserts |
|---|---|
| `hh` | `=>` |
| `aa` | `@` |
| `uu` | `_` |

---

## Pane vs. window navigation (intended behavior)

Two **separate** key sets, on purpose:

- **Inside Vim**, `Ctrl-h/j/k/l` moves between Vim splits (no prefix).
- **In tmux**, use the `C-a` prefix to move between tmux panes/windows.

There is intentionally **no** vim-tmux-navigator unifying these — Vim keys stay
inside Vim, tmux keys (prefixed) stay in tmux.

---

## Not installed (despite vimrc header)

The vimrc header advertises `,f` (fuzzy find files) and `,b` (fuzzy buffers), but
**no fuzzy-finder plugin (fzf/ctrlp) is installed** — those keys currently do
nothing. Add fzf.vim to `VIM_PACKAGES` in `setup.sh` if you want them.
</content>
</invoke>
