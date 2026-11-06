# Ghost claude-task runner

Designed Nov 5, 2026 (Todoist: "Design the Ghost claude-task runner…", 65 Ghost). Built by the Todoist task "Build the Ghost claude-task runner" (65 Ghost, `pair`), which works from this doc.

## What it does

Every 15 minutes, around the clock, a systemd user timer runs a shell check that asks Todoist, with no model, whether a `claude` task can be taken now. Empty: one log line, exit, no cost. A hit: one headless Opus session runs the `run` skill unattended. It picks the next task in the skill's strict order, works it, records it, and leaves anything that needs a person as an outbox task (`[Approve]`, `[Answer]`, `[Review]`, `[Stuck]`) for `/next`. One task per run, never two runs at once.

It replaces the cloud "Claude task run" routine (`trig_01BmTczbLeALX8Gxi6oKx2cH`). That routine runs at 6:46, 10:46, 14:46 and 18:46 ET: a Haiku dispatcher picks, an Opus subagent works each task, and a Sonnet subagent checks the result, up to three tasks a run. Ghost picks work up within 15 minutes, checks for free, and runs next to Ghost's repos and tools.

## Decisions

| | Decision | Why |
|---|---|---|
| Check | `bin/claude-task-check`: bash + curl + jq against Todoist API v1 | Free. REST v2 is gone (410) |
| Kick-off | The check only gates; the Opus session picks and works (reopened: question 1) | The pick order lives in one place, the run skill |
| Schedule | Every 15 min, all day | An empty check costs nothing; a failing task is held 8 h, so nothing loops |
| Email | Draft-only: send, reply and forward are denied; a send becomes a draft plus a `Send:` to-do | No run can send mail |
| GitHub | Always a branch, pushed, with a PR; never `main`, never a merge; `main` carries a ruleset | Merging stays John's |
| Guardrails | `--permission-mode auto` + a deny list | The skill's gate is the first line; the deny list and the ruleset hold anyway |
| Repo | This one, as Linux-only files | It already rebuilds Ghost |
| Secrets | Todoist token in `~/.keys/todoist` only; Claude login by `claude /login` | Nothing committed |
| Alerts | A failed run files one Todoist task in 65 Ghost and pauses the runner until it's closed | `/next` is where it gets seen |
| Logs | One JSON result per run, kept a year | A year of what the runner did and what it cost |
| Cut-over | Turn off the cloud run once Ghost's runner is running | The two never race for a task |

## Files

All new and Linux-only; add them to the Ubuntu-only table in `CLAUDE.md`.

| File | Linked to | What |
|---|---|---|
| `bin/claude-task-check` | `~/.local/bin/claude-task-check` | The check, the kick-off, and (`--alert`) the failure task |
| `systemd/claude-task-run.service` | `~/.config/systemd/user/` | Oneshot that runs the check |
| `systemd/claude-task-run.timer` | `~/.config/systemd/user/` | Every 15 min |
| `systemd/claude-task-alert.service` | `~/.config/systemd/user/` | `OnFailure=` target: `claude-task-check --alert` |
| `claude/task-runner-settings.json` | Not linked; passed with `--settings` | The deny list |
| `keys/todoist` | Template only | `export TODOIST_API_TOKEN="your key here"` |
| `bin/protect-main` | `~/.local/bin/protect-main` | Puts the `main` ruleset (Guardrails) on a repo with `gh api`; skips a repo that already has it |

`setup-ubuntu.sh`:
- Add the five linked files to the `links` list, beside `bin/newrc` and the other units.
- In `phase_systemd`, `systemctl --user enable --now claude-task-run.timer` only when `~/.keys/todoist` holds a real token (not the template); otherwise `warn`. Same skip-not-fail pattern as `browser-vnc` waiting for `~/.vnc/passwd`.
- Create `~/workspaces/claude-task-runs` (the run's working directory) and `~/.local/state/claude-task-run` (results).

`CHEATSHEET-ubuntu.md`: status `systemctl --user list-timers claude-task-run.timer` · logs `journalctl --user -u claude-task-run -n 50` · run now `systemctl --user start claude-task-run` · check only `claude-task-check --dry-run` · pause `systemctl --user stop claude-task-run.timer`.

## The check

1. `flock -n "$XDG_RUNTIME_DIR/claude-task-run.lock"`, or exit 0. systemd already won't start the oneshot while it's active; the lock covers a manual run.
2. Read only `~/.keys/todoist` for `TODOIST_API_TOKEN`. Never source all of `~/.keys`: it holds `ANTHROPIC_API_KEY`, which would put the run on API billing.
3. Paused? An open task whose title starts `Ghost runner failing` (filter `search: Ghost runner failing`) means the last run failed and nobody has looked yet: log `paused: alert open` and exit 0.
4. `GET https://api.todoist.com/api/v1/tasks/filter?query=<urlencoded>` with `Authorization: Bearer $TODOIST_API_TOKEN`. The query is the run skill's step-1 filter, verbatim: `@claude & !@then & !#Proposed & (no date | overdue | today)`.
5. Drop every task whose due has a time still ahead. A held or leased task (lease 2 h, hold 8 h) matches `today`, and without this every lease would start Opus for nothing. Compare against `TZ=America/New_York date +%Y-%m-%dT%H:%M:%S`; Todoist floating times are local time. A due with `Z` or an offset converts first.
6. Nothing left: log `no claude tasks`, exit 0. One passing task is enough, so follow `next_cursor` only while a page passes nothing.
7. Otherwise start the run (below). `--dry-run` stops here and prints the passing tasks.

Any curl or HTTP failure exits non-zero, so systemd marks the unit failed and the alert fires.

## The run

```sh
env -u ANTHROPIC_API_KEY "${CLAUDE_BIN:-$HOME/.local/bin/claude}" -p "$PROMPT" \
  --model opus \
  --permission-mode auto \
  --settings "$REPO_DIR/claude/task-runner-settings.json" \
  --output-format json \
  > "$HOME/.local/state/claude-task-run/$(date +%Y-%m-%dT%H%M).json"
```

- Working directory `~/workspaces/claude-task-runs`; a task that needs a repo goes to it from there.
- `$PROMPT`: copy the cloud "Claude task run" task's prompt when building, so both say the same thing, minus any picker/worker hand-off. Here one Opus session picks and works (question 1 would keep the hand-off). Add the two Ghost rules from Guardrails: email is draft-only, and GitHub work goes on a branch with a PR.
- `--model opus` is the alias, so a new Opus is picked up with no edit.
- After the run: print the finish line (`jq -r .result`) to the journal; delete result files older than a year (`find … -mtime +365 -delete`).
- claude exits non-zero → the script exits non-zero → the alert.
- A finish line of `No claude tasks.` means the check and the skill disagree about what can be taken: exit non-zero with that reason, so the alert pauses the runner instead of starting Opus every 15 minutes for nothing.
- This session has the Agent tool, so the run skill's step-6 fresh reviewer runs inside it.

## Units

`claude-task-run.service`:

```ini
[Unit]
Description=Claude task runner: check Todoist, run one claude task on a hit
OnFailure=claude-task-alert.service

[Service]
Type=oneshot
WorkingDirectory=%h/workspaces/claude-task-runs
ExecStart=%h/.local/bin/claude-task-check
TimeoutStartSec=45min
```

For a oneshot, `TimeoutStartSec` bounds the whole run (it is off by default for this type).

`claude-task-run.timer`:

```ini
[Unit]
Description=Claude task check every 15 minutes

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
```

`claude-task-alert.service`: `Type=oneshot`, `ExecStart=%h/.local/bin/claude-task-check --alert`.

## Guardrails

**Email is draft-only.** `send_message`, `reply` and `forward` are denied, so no run can send mail. A task that ends in an email gets a draft (`create_draft`, read back with `get_draft`) and a to-do for John to send it: a `quick` task in the task's project titled `Send: <draft subject>`, with a one-line description and a brief naming the draft, the recipient and the task it came from. The send is his, so it's a to-do, not an `[Approve]`.

**GitHub work goes on a branch, with a PR.** The run creates a branch, commits, pushes the branch and opens a PR with `gh pr create`. The PR link goes in the record and the `[Review]`. It never pushes `main` and never merges; merging is John's. Before its first push to a repo, the run checks `gh ruleset check main --repo <owner>/<repo>`. If the pull-request rule isn't there, the work stays a local commit and the record says so.

**The `main` ruleset** (`bin/protect-main <owner>/<repo>`): require a pull request (no approvals, so John merges his own), block force pushes, block deletion, and no bypass list. The missing bypass list matters: the run pushes as `softwaregravy`, an admin, so a rule that admins can bypass wouldn't stop it. John merges through PRs too, as he already does. Rulesets are free on public repos, and the private ones (figaro, arrivalpack, watchplan) can take them too: `branches/main/protection` answers "not protected" there, not "upgrade".

**Deny list**, `claude/task-runner-settings.json` → `permissions.deny`:

- Gmail: `send_message`, `reply`, `forward`, `trash_message`, `trash_thread`, `delete_draft`, `delete_label`, `mark_message_spam`, `mark_thread_spam`
- Calendar: `create_event`, `update_event`, `delete_event`, `respond_to_event`
- Drive: `share_file`, `trash_file`, `update_file`
- Todoist: `delete-object`, `manage-assignments`
- Bash: pushes to `main` (`git push * main`, `git push * HEAD:main`), force pushes (`git push --force *`, `git push -f *`), `gh pr merge *`, `gh api *`, `gh repo edit *`, `gh repo delete *`

Use full names: `mcp__claude_ai_Gmail__send_message`, `mcp__todoist__delete-object`, `Bash(git push * main)` (check the rule syntax against `claude --help` when building). A denied call comes back to the model as an error. Bash rules match by pattern and miss some forms of a push, so the ruleset is what keeps `main` safe; the deny list catches the common slip.

## Secrets

- Todoist API token: Todoist → Settings → Integrations → Developer. Save it in the password manager, then on Ghost write `~/.keys/todoist` from the `keys/todoist` template and `chmod 600`. Do this by hand and never paste the token into a chat. It has full account access; only the check and the alert read it.
- Claude login: `~/.claude/.credentials.json`, made by `claude /login` after a rebuild, never committed. Runs use this subscription login, never API billing.
- Todoist MCP (OAuth, `https://ai.todoist.net/mcp`) and the claude.ai connectors (Gmail, Calendar, Drive) are user-scoped on Ghost, so headless runs get them. After a rebuild, `/mcp` re-authorizes Todoist.

## Logs and alerts

- journald: `journalctl --user -u claude-task-run`. One line per empty check; the finish line per run.
- `~/.local/state/claude-task-run/*.json`: each run's full result (finish line, cost, session id), kept a year. journald rotates by size and may not reach back that far, so these files are the record.
- Failure (a curl or HTTP error; claude exiting non-zero for an expired login or a usage limit; the 45-minute timeout; `No claude tasks.` after a hit): `OnFailure=` runs `claude-task-check --alert`. If no `Ghost runner failing` task is open, it adds one in 65 Ghost (`6hqWrPwCmjp299R2`): title `Ghost runner failing: <reason>`, label `quick`, no dates, a one-line description, and a first comment with WHY and HOW (`journalctl --user -u claude-task-run -n 50`, `claude-task-check --dry-run`). While it's open the runner is paused (check step 3). Closing it resumes the runner.
- If Todoist itself is what's failing (bad token, outage), the alert can't file, and the failure shows only in journald.
- Normal outcomes need nothing new: they arrive as outbox tasks on `/next`'s Your call line.

## Cut-over

Once the runner is running (the timer's checks are clean in journald and one real task has run end to end), turn off the cloud "Claude task run" scheduled task in the same sitting. No overlap.

## Build checklist

1. Todoist API token → password manager → `~/.keys/todoist`, by hand.
2. On branch `ghost-task-runner` (this doc is on it): the files above, the `setup-ubuntu.sh` wiring, the `CLAUDE.md` and `CHEATSHEET-ubuntu.md` rows.
3. `protect-main softwaregravy/system_files`, then each other repo the runner will work in; `gh ruleset check main --repo <repo>` shows the three rules.
4. Run `setup-ubuntu.sh`'s link and systemd phases to link and enable.
5. `claude-task-check --dry-run`: the passing tasks match what `/next claude` would pick.
6. One real run: `systemctl --user start claude-task-run`; read the JSON and the task's record in Todoist.
7. Alert path: force a failure (`CLAUDE_BIN=/bin/false`). One `Ghost runner failing` task appears, the next check logs `paused: alert open`, and closing the task resumes it.
8. Guardrails, with `claude -p --settings claude/task-runner-settings.json`: a send to yourself and `git push origin main` both come back refused; a throwaway branch pushes and opens a PR. Close that PR and delete the branch.
9. PR; merge on a go; pull on Ghost.
10. Cut-over, as above.

## Open

- Usage limits: this design session ran Opus 5.5 on Ghost's login, so headless Opus works on the plan. What runs every 15 minutes do to the 5-hour and weekly limits is unknown; look after the first busy day.
- API v1's response shape (`results`, `next_cursor`, where the due time sits): confirm on the first dry run.
- The run skill's step 1, step 6 and Finish describe the cloud run (a smaller model picks; the worker has no Agent tool). On Ghost one Opus session does both. Reword the skill once Ghost is the only runner; that's a skill edit, so it needs a go.
- The run skill's gate turns an unattended send into an `[Approve]`, and files unattended to-dos in `Proposed`. The Ghost prompt overrides both for email (a draft plus a real `Send:` task). Fold that into the skill; that's a skill edit, so it needs a go.
- A run killed by the timeout leaves no record on its task. The alert says what happened, and the task's 2-hour lease brings it back once the runner resumes.

## Questions to settle

Round 1 of a design grilling, Nov 5, 2026. Each item gives the recommendation; none is decided yet.

1. **Reuse the cloud prompt as-is.** Start `claude -p --model haiku` with the cloud routine's prompt verbatim (Haiku dispatcher, Opus worker, Sonnet checker, up to three tasks, a stop recorded when a worker returns nothing), plus the Ghost rules. This replaces one Opus session that picks, works and checks itself. Recommended: yes. The prompt is tested, the checker is independent, and the free check makes a Haiku start cheap.
2. **An open alert pauses the runner** until it's closed. Recommended: yes. A broken login or a hung run can't keep starting sessions.
3. **A hit that takes nothing is a failure** (alert, then pause), not just a log line. Recommended: yes.
4. **The send to-do rides on the `[Review]`.** Its description leads `SEND: '<subject>' to <recipient>`, so it shows first on /next's Your call line. The alternatives are a plain `quick` task (drawn at random) or a new `[Send]` outbox kind (edits to /next, run and sweep). Recommended: the Review.
5. **No bypass list on the `main` ruleset**, so John also merges through PRs. Recommended: yes. An admin bypass would let the runner through.
6. **The runner works in its own clones** under `~/workspaces/claude-task-runs/<repo>`, never in John's checkouts (`system_files` is the live dotfiles). Recommended: yes.
7. **Calendar and Drive writes stay denied.** A task that needs one ends in an `[Approve]`, answered from another surface. Recommended: yes.
8. **Runner sessions load no plugins** (`egm` and `mattpocock-skills` off in `task-runner-settings.json`). Recommended: yes.
9. **The build is a GitHub issue** (`ready-for-human`) plus the Todoist `pair` task pointing at it, per this repo's issue tracker. Recommended: yes.

Round 2 waits on these: the timeout and a daily cap (depend on 1), where this doc ends up (depends on 9), when `main` gets protected (depends on 5), and which skill edits come along (depend on 1 and 4).
