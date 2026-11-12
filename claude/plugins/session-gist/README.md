# session-gist

A Claude Code mod that keeps a three-line summary above the prompt, so each
session says what it is about at a glance:

```
Session: Adding session summaries to Claude Code interface
Last: Asking if session summaries can appear near the top
Claude: Enabled the session-gist mod; summary row appears after the next answer
```

Every line is written by Haiku: the Last line when you send a prompt, all
three when the answer ends. Each session's latest summary is kept in the
plugin store (the newest 300), so a resumed session shows its row at once.

It is installed from this folder's marketplace (`claude/plugins`), declared
in `extraKnownMarketplaces` and `enabledPlugins` in the Claude settings files.
Claude Code reads it from here, so after an edit run `/reload-plugins`.
