# Plan v2.1: Claude-driven issue → PR workflow

Status: agreed design, not yet built. v2 written 2026-09-28 after a critique of v1; v2.1 adds the quickstart, worked example, decisions on open questions, and the future-improvements list. §14 lists what changed and why. Facts about Claude Code surfaces were verified against the docs on 2026-09-27 (sources in §18).

**This document is the only thing that carries over between sessions.** Nothing in any Claude session's memory survives. When revising it, keep §0, §5, §6, §16 and §17 intact or updated, never dropped.

## 0. How you use it (the whole workflow)

```
1. File an issue with the form. Leaving the optional fields blank is fine.
2. Anywhere Claude runs:  /go 42
   Claude interviews you, posts a spec and a plan on the issue, and says:
   "Comment @claude go on the issue to approve."
3. On the issue:  @claude go
   A PR appears as claude[bot]. Claude fixes what review and CI find.
4. Approve. Merge. The issue closes.

Lost?     /go 42 status        (or read the last comment on the issue)
Wrong?    /go 42 reset         (start over; spec and plan are kept)
Partial?  /go 42 from plan     (redo from a phase)
Stuck PR? @claude go  on the PR (fix what's open), or fix it yourself and merge
```

Every issue gets this text as its first comment (§8, `welcome.yml`), and `go` prints the relevant line as "Next: …" after every step. You never need to remember it.

## 1. Goal

Work is planned with Claude, recorded as GitHub issues, and executed one issue at a time without me driving a session by hand:

1. An issue exists: filed quickly by me through a form, or written by Claude from a higher-level feature session.
2. Before any code: deliverables and acceptance criteria are clear, and an implementation plan is agreed.
3. Claude implements, tests, self-reviews, and opens a PR.
4. Claude fixes what review and CI find until the PR is clean.
5. I read, approve, merge.

I should never have to remember the workflow. There is one command, and Claude always says what happens next.

## 2. Principles

- **One command: `go`.** `/go 42` in any Claude session; `@claude go` on GitHub. It works out where the issue is and does the next step. Every phase ends with "Next: …".
- **The issue is the only shared state.** Phases read from and write to the issue. State is *derived from facts* on the issue (which comments exist, whether a PR is linked, PR review state), never stored in labels. Labels are display.
- **Thinking wants persistence; executing wants a clean slate.** The design conversation runs in one persistent interactive session where I am. Implementation runs fresh, from a written spec and plan.
- **Claude authors, I review.** Anything that writes code or opens a PR runs as `claude[bot]` (GitHub Action), so I'm a distinct reviewer and can approve.
- **Loops converge inside one job.** Review-and-fix happens inside the implementation run with a fresh-context subagent, before the PR opens. The external loop is the fallback.
- **Repo files carry facts; the plugin carries procedure.** `CLAUDE.md` says how this repo builds and tests. The plugin says how an issue becomes a PR. Neither references the other.
- **Two surfaces only.** My session (terminal, cloud session, phone, later Projects) and GitHub Actions. No routines, no API bridges.

## 3. Architecture

```
  ┌────────────────────────────────────────────────────────────────────────┐
  │ GitHub issue (form-templated). Spec, plan, PR link, outcomes = comments │
  └────────────────────────────────────────────────────────────────────────┘
        ▲            │ "@claude go"                    │ "@claude go"
        │            │ no approved plan                 │ approved plan
        │            ▼                                  ▼
        │   Action replies:                    Action: claude.yml (claude[bot])
        │   "Run /go 42 in a session"          /go 42 → implement → local tests
        │            │                          → self-review (fresh subagent)
        │            ▼                          → fix → … clean → open PR
        │   My session (terminal / cloud /                │
        │   phone): /go 42                                ▼
        │   interview → spec → plan            Action: claude-review.yml
        │   → "approve?"                       /go <pr> → findings + verdict
        └── posts spec + plan as comments               │
            I comment "@claude go" ─────┐               │ findings > 0 (or CI red)
                                        │               ▼
                                        │      Action: claude.yml (fix branch)
                                        │      /go <pr> → fix → push → re-review
                                        │               │ clean + CI green
                                        │               ▼
                                        └──▶  me: approve → merge → issue closes
```

My touches: file the issue, one design conversation, `@claude go`, Approve.

## 4. Components

### 4.1 `softwaregravy/claude-plugins` (new, public)

Marketplace repo with one plugin, `workflow`. Public so the Action can fetch it without credentials.

```
claude-plugins/
├── .claude-plugin/marketplace.json
└── plugins/workflow/
    ├── .claude-plugin/plugin.json
    ├── skills/
    │   ├── go/SKILL.md                  # dispatcher: the only user-facing skill
    │   ├── go-plan/SKILL.md             # design conversation → spec + plan (internal)
    │   ├── go-implement/SKILL.md        # plan → code → tests → self-review → PR (internal)
    │   ├── go-review/SKILL.md           # PR findings + verdict (internal)
    │   ├── go-fix/SKILL.md              # address findings / CI, push (internal)
    │   ├── go-reset/SKILL.md            # restart / cleanup (internal, via `/go N reset`)
    │   ├── feature-to-issues/SKILL.md   # big-picture session → templated issues
    │   └── init-repo/SKILL.md           # copy the per-repo bootstrap into a repo
    ├── templates/
    │   ├── spec.md, plan.md             # shared headings and rules (§6)
    │   ├── ISSUE_TEMPLATE/{task.yml, config.yml}
    │   ├── workflows/{claude.yml, claude-review.yml, agent-approval-check.yml, sweep.yml}
    │   └── actions/setup/action.yml     # composite setup action stub
    └── README.md                        # the workflow, written for a reader who forgot it
```

Internal skills use `disable-model-invocation: true` and are invoked only by `go`. All side-effecting skills declare `allowed-tools` explicitly (§10).

Distribution:

| Surface | How the skills get there |
|---|---|
| Terminal | `/plugin marketplace add softwaregravy/claude-plugins`, `/plugin install workflow@<marketplace-name>` |
| GitHub Action | `plugin_marketplaces` + `plugins` inputs |
| Cloud sessions | Enable the skills on my claude.ai account (cloud sessions load account-enabled skills; they don't load plugins declared in a repo) |
| Projects (when available) | Project settings → Plugins |

### 4.2 Per-repo bootstrap (`/init-repo`)

- `.github/ISSUE_TEMPLATE/task.yml`, `config.yml`
- `.github/workflows/claude.yml`, `claude-review.yml`, `agent-approval-check.yml`, `sweep.yml`
- `.github/actions/setup/action.yml`: the composite that installs toolchain, deps, services. `init-repo` reads the repo's existing `ci.yml`, extracts its setup steps into this composite, and points `ci.yml` at it, so Claude's jobs and CI share one environment. A Claude-assisted, one-time refactor per repo, not a convention to follow by hand
- `CLAUDE.md` must name: test, lint, typecheck commands; branch and PR conventions. No `bin/test` convention is assumed; see §5 for how the test command is found
- Labels (display only): `claude:designing`, `claude:implementing`, `claude:pr-open`, `claude:blocked`, `claude:done`
- One secret: `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`; bills the Max subscription)
- Ruleset on `main`: require PR; required checks = CI and `agent-approval-check`; 1 approval; no force-push. `claude-review` is **informational in v1**, not required (§7 phase 3 explains why)

### 4.3 GitHub App and identity

Claude GitHub App installed on the repo (already required for cloud sessions). The Action authenticates as the App by default, so its commits, comments, and PRs appear as `claude[bot]`. Never pass `github_token` to the Action: it changes the identity and stops Claude's pushes from triggering other workflows. My sessions (terminal, cloud) act as me; they only ever write spec and plan comments, never code.

## 5. The `go` dispatcher

`/go <issue-or-pr> [reset | from <phase> | status]`. On every call:

1. Read the issue: body, comments, labels, linked PRs, PR checks and review state.
2. Derive the phase from facts:

| Facts on the issue | Phase | What `go` does |
|---|---|---|
| No `<!-- go:spec -->` comment | needs spec | Interactive: run `go-plan`. In an Action: reply with how to start a session and stop |
| Spec, no `<!-- go:plan -->` | needs plan | `go-plan` (plan only; interview skipped) |
| Plan, no `<!-- go:approved -->` | awaiting approval | Interactive: ask. In an Action: `@claude go` from a write-access user *is* approval; `go` posts the approved marker and continues |
| Approved, no linked open PR | implement | Action only: `go-implement`. Interactive: say so and offer to trigger by commenting |
| Open PR, verdict findings > 0 or CI red | fix | `go-fix` |
| Open PR, clean + green | awaiting me | Post status; request my review if not yet requested |
| PR merged | done | Label `claude:done`, summarize |
| "blocked by #N" open | blocked | Say so; do nothing |

3. Do the step. 4. Post one comment: what it did, outcome, link to the run or session. 5. Set the display label. 6. End with "Next: …" using the matching line from §0.

`/go 42 status` does steps 1–2 and prints. `/go 42 reset` and `from <phase>` are in §11.

**How the test command is found.** Nothing assumes a `bin/test`. During design, `go-plan` reads, in order: `CLAUDE.md`; the repo's CI workflow (the truth about how tests actually run); then `package.json` scripts, `Makefile`, `Rakefile`, `pyproject.toml`, or equivalents. If still ambiguous it asks me once. The resulting commands (test, lint, typecheck) are written into the plan's header, so `go-implement` and `go-fix` never guess.

## 6. Spec and plan templates

Headings are fixed so the form, `feature-to-issues`, and the skills agree.

**Issue form (`task.yml`)** — Problem (required); Deliverables, Acceptance criteria, Out of scope, Notes (optional). Blank optional sections are what `go-plan` interviews about. `config.yml` leaves blank issues enabled for notes not meant for Claude.

**Spec rules** (`templates/spec.md`), enforced by `go-plan`:

- Every acceptance criterion is a check someone could run: *given X, expect Y*, with at least one concrete example.
- Out-of-scope is explicit, even if "none".
- Dependencies: "blocked by #N" in Notes.
- The spec is posted as one comment starting with `<!-- go:spec v1 -->`; revisions post a new comment with a bumped version.

**Plan rules** (`templates/plan.md`):

- Header: goal, approach, files touched, spec version it implements, and the verification commands (test, lint, typecheck) discovered per §5.
- **Criterion → test map** before any task: each acceptance criterion names the test that verifies it.
- Tasks in order, each with exact file paths, the test to write first, the verification command, and a commit message. Small enough that one task is one commit.
- Posted as one comment starting with `<!-- go:plan v1 -->`; copied into the PR as `docs/plans/<n>-<slug>.md`.

Claude-authored issues (from `feature-to-issues`) arrive with the spec sections filled and `### Parent` linking the feature issue, so `go` skips straight to planning.

## 7. Phases

### Phase 1: design (my session)

Trigger: I run `/go 42` in a session, or `@claude go` on an issue without a spec makes the Action reply "Start a session in this repo and run `/go 42`" (from a phone: claude.ai/code → new session in the repo). No session is created from GitHub.

`go-plan`: read issue and parent → subagents explore the codebase → interview me with `AskUserQuestion` only about blank sections → post spec → pre-mortem (risks, edge cases, what tests would miss) → write plan → post plan → "Approve?" If yes, I'm asked to comment `@claude go` on the issue (a clickable link is posted). The session never flips state on my behalf; approval is always my comment.

Comments this session posts appear under my GitHub name (cloud and terminal sessions act as me). Each ends with the footer `— written by Claude in a design session`.

### Phase 2: implement (Action, `claude[bot]`)

Trigger: `@claude go` on an issue with a plan and no open PR. `claude.yml` runs the composite setup, then `claude-code-action` with `prompt: "/go 42"`.

`go-implement`:
1. Refuse if a blocker issue is open or the plan's spec version is stale (spec revised after plan).
2. Branch `claude/42-<slug>` from current `main`; commit the plan file.
3. For each task: write the test, implement, run the plan's test command locally in the runner. Many local runs, no CI runs.
4. Self-review loop: a reviewer subagent with fresh context receives the diff, the plan file path, and the criterion→test map explicitly (our own prompt, so nothing depends on `/code-review` locating the plan); `/code-review` runs alongside it for the bug hunt. Fix; re-run tests; repeat until both are clean.
5. Blocked → comment the question on the issue, label `claude:blocked`, stop.
6. `gh pr create` with "Closes #42", body = spec summary, criterion→test map, link to plan. Comment the PR link on the issue.

Push count: one, when the PR opens. CI runs once.

### Phase 3: PR review (Action, `claude[bot]`)

Trigger: `pull_request` opened / synchronize / ready_for_review, same-repo branches only. `claude-review.yml` → `go-review`.

- Inline findings with stable IDs and severities. First pass is the criterion→test map: a criterion without a passing test is Important.
- Verdict comment whose body **starts with** `<!-- go:review pr=123 round=2 findings=3 -->`.
- Convergence rules: round 2+ reports Important and regressions only; never reopens an ID resolved with a reason, whether the fixer or I resolved it; if the same ID survives two rounds, stop and request my review instead of another round.
- **Not a required check in v1.** If it were, a finding the fixer can't resolve would keep the PR red with no way through except an admin bypass. As information, findings can't be infinite: the reviewer only reports on the current diff and honors resolved threads. My discretion is exercised with ordinary PR actions: resolve a thread ("not doing this"), comment `@claude go` to have it fixed, or approve and merge. Revisit making it required after the measurement checkpoint (§13).

### Phase 4: fix (Action, `claude[bot]`)

Trigger, in `claude.yml`: `issue_comment` on a PR whose body starts with the review marker and author is `claude[bot]` (`allowed_bots: claude[bot]`), with `findings > 0`; or `workflow_run` of CI concluded failure on a same-repo PR; or `@claude go` on the PR.

`go-fix`: merge `main` into the branch first (never rebase or force-push; my commits are kept) → address each finding or the CI failure → reply on each thread (fixed, or won't fix with reason, and resolve) → run the plan's test command locally → push once. The push re-runs review and CI.

No round cap. Stop conditions are the reviewer's convergence rules and CI green.

### Phase 5: me

Read the PR (plan file is in the diff), approve, merge. `agent-approval-check` (required) blocks merging `claude[bot]` commits without a human approval. Merge closes the issue; the next `/go` or the sweep labels it done.

### Phase 0: feature session (optional front end)

`feature-to-issues` in any interactive session: one big-picture interview, then templated issues with parent links and "blocked by" dependencies. Nothing starts until I `@claude go` each one, so ordering stays mine.

## 8. Workflows

`claude.yml` (one file, three jobs):

```yaml
on:
  issue_comment: { types: [created] }
  workflow_run: { workflows: [CI], types: [completed] }
concurrency: { group: go-${{ github.event.issue.number || github.event.workflow_run.pull_requests[0].number }}, cancel-in-progress: false }

jobs:
  go-issue:     # "@claude go" on an issue → implement (or reply how to plan)
    if: github.event_name == 'issue_comment' && !github.event.issue.pull_request
        && startsWith(github.event.comment.body, '@claude go')
    permissions: { contents: write, issues: write, pull-requests: write, id-token: write, actions: read }
    steps:
      - uses: actions/checkout@v6
      - uses: ./.github/actions/setup
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          plugin_marketplaces: https://github.com/softwaregravy/claude-plugins.git
          plugins: workflow@<marketplace-name>
          prompt: "/go ${{ github.event.issue.number }}"
          claude_args: --max-turns 120 --allowedTools "<list in §10>"
      - if: always()     # never leave the issue without a status
        run: gh issue comment "$N" --body "…outcome + run link…" && gh issue edit "$N" --add-label …

  go-pr:        # review verdict with findings, or "@claude go" on a PR → fix
    if: github.event_name == 'issue_comment' && github.event.issue.pull_request
        && ( startsWith(github.event.comment.body, '@claude go')
          || (github.event.comment.user.login == 'claude[bot]'
              && startsWith(github.event.comment.body, '<!-- go:review ')
              && !contains(github.event.comment.body, 'findings=0')) )
    with: { allowed_bots: "claude[bot]", prompt: "/go ${{ github.event.issue.number }}", … }

  go-ci:        # CI failed on a same-repo PR → fix
    if: github.event_name == 'workflow_run' && github.event.workflow_run.conclusion == 'failure'
        && github.event.workflow_run.pull_requests[0]
        && startsWith(github.event.workflow_run.head_branch, 'claude/')
```

`claude-review.yml`: `pull_request` events → setup → `claude-code-action` with `prompt: "/go <pr>"` and review-only tools. The job succeeds whenever the review completes; findings are in the verdict comment, not the job status (informational in v1).

`welcome.yml`: `issues: [opened]`, no Claude, no secrets. Posts the §0 text plus the naming table (§16) as the issue's first comment, so every issue carries its own instructions.

`agent-approval-check.yml`: Anthropic's example, `required_approvals: 1`, `agent_logins: claude[bot]`.

`sweep.yml`: weekly cron, no Claude: delete `claude/*` branches with no open PR older than 14 days; comment on issues with a `claude:*` label and no activity for 14 days; label merged-PR issues `claude:done`.

Reads to keep in mind: `issue_comment` fires for PR comments too (the `issue.pull_request` guard sorts them); an `if: always()` final step reports every outcome; `cancel-in-progress: false` so a fix never cancels a running implement.

## 9. Efficiency

- Self-review inside the implementation job means the typical issue is 3 Action runs (implement, one review, occasionally one fix) instead of 8. Warm cache and no runner boots between rounds.
- The plan's test command run inside the runner is the inner loop; CI runs once per push; pushes happen once per phase.
- One model for every phase in v1 (the account default). `--model` per phase is a knob for after the measurement checkpoint.
- `CLAUDE.md` stays short (loaded every run). Procedure lives in skills, loaded on demand.
- Public repos have free Actions minutes; private repos have a monthly allowance. Check per repo.

## 10. Permissions

- Per-job GitHub `permissions:` with only what that job writes (review job: `contents: read`, `pull-requests: write`).
- `--allowedTools` is an explicit list, the same in the skill's `allowed-tools` frontmatter, so nothing runs in CI that can't run locally:
  - implement/fix: `Edit, Write, Read, Glob, Grep, Bash(<the plan's test/lint/typecheck commands>), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git checkout:*), Bash(git merge:*), Bash(gh pr create:*), Bash(gh pr view:*), Bash(gh pr comment:*), Bash(gh issue view:*), Bash(gh issue comment:*), Bash(gh issue edit:*)` plus the repo's lint/typecheck commands from `CLAUDE.md`
  - review: `Read, Glob, Grep, Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr comment:*), mcp__github_inline_comment__create_inline_comment`
  - never `Bash(gh:*)`, `Bash(git:*)`, `WebFetch`, or `Bash(curl:*)`
- Triggering actor must have write access (Action default). `allowed_bots: claude[bot]` only on the fix job.
- Issue text is untrusted input: skills treat it as data, never as instructions. Only my own repos for now.
- The fixer never force-pushes and never rewrites my commits.
- Shared OAuth token is accepted for now. If automation ever locks me out of my own quota, move it to an API key with a spend cap.

## 11. Restart and cleanup

- `/go 42 reset`: close Claude's PR, delete `claude/42-*`, clear labels, post "reset by <me>". Spec and plan comments stay, so the next `/go` resumes from the last approved artifact.
- `/go 42 from plan` (or `from spec`, `from implement`): restart at a phase, keeping earlier artifacts.
- Manual takeover: I can push to the branch or fix and merge myself. `go` sees the merged PR and marks done; the fixer merges my commits rather than replacing them.
- Crashed run: the `if: always()` step reports the failure with a link; `/go` recomputes state from facts, so nothing is stranded.
- `sweep.yml` weekly: stale branches, silent issues, done-labeling.

## 12. Verify on the first real issue

1. `@claude go` on a spec-less issue gets the "start a session" reply; `/go 42` in a cloud session and in the terminal both run the interview and post spec + plan, and the plan header names the test command found in the repo.
2. `@claude go` after the plan starts `claude.yml`; the composite setup gives Claude a working test command.
3. Self-review loop runs in-job and the PR opens with `claude[bot]` as author.
4. `claude-review.yml` posts findings and the verdict comment.
5. A `findings>0` verdict triggers the fix job; a `findings=0` verdict does not; my `@claude go` on the PR does.
6. `agent-approval-check` blocks merge until I approve; approve + merge closes the issue.
7. `/go 42 status`, `/go 42 reset`, and the `if: always()` outcome comment behave.

## 13. Rollout

1. **Plugin repo + `go`, `go-plan`, templates, README (§0 + §16).** Test `/go` locally against a real issue in `system_files`. Use `claude plugin eval` to give the skills a regression suite from the start. No Actions yet.
2. **Bootstrap one repo:** form, `welcome.yml`, labels, composite setup (extracted from that repo's CI), `claude.yml` (implement only), token, ruleset, `agent-approval-check`. Verify 1–3, 6.
3. **Review:** `go-review`, `claude-review.yml`. Verify 4. Fix by hand or with `@claude go` on the PR.
4. **Automatic fix:** enable the verdict and CI triggers. Verify 5, 7. Add `sweep.yml`.
5. **Front end and second repo:** `feature-to-issues`, `init-repo`.
6. **Measurement checkpoint, after five real issues.** Collect: Action runs per issue, review rounds, minutes per run, wall time issue→PR, minutes of my attention, findings I'd call wrong, times I used `reset`. Decide from numbers: model per phase, whether `claude-review` becomes required, what to simplify next.
7. **Later:** see §17.

### Decisions taken on open questions (v2.1)

| Question | Decision for v1 |
|---|---|
| Marketplace name | `softwaregravy`, so the plugin is `workflow@softwaregravy` |
| Model per phase | One model, the account default, for all phases; revisit at the checkpoint |
| Test command | Discovered per §5 and written into the plan; no `bin/test` convention |
| Runner environment | `init-repo` extracts CI's setup into a composite action, shared with CI |
| Does `/code-review` see the plan? | Not relied on: the in-job reviewer is our own subagent prompt that receives the plan path; `/code-review` runs alongside for bugs |
| Spec comments under my name | Accepted; footer "— written by Claude in a design session" |
| `claude-review` required? | No, informational; my approval is the gate |

## 14. What changed from v1 and why

| v1 | v2 | Why |
|---|---|---|
| Action → routine `/fire` → session URL on the issue | Action replies "run `/go 42`"; I start the session | Removed a research-preview endpoint, a per-repo routine and token, and an unverified pause behavior. Costs one manual step |
| Several user-facing skills and labels to remember | One command, `go`, that dispatches and says what's next | Brain-dead by design |
| Labels as state | State derived from issue facts; labels display only | Stuck labels can't strand work |
| Design session flips `claude:go` as me | Approval is always my `@claude go` comment | Human approval is distinguishable from automation |
| External review/fix loop, round cap 3 | Self-review loop inside the implement job; external loop as fallback; no cap, convergence rules + stall detection | Fewer runs, warmer cache; I'm the backstop |
| "Never skip a test" rule | Test-shaped acceptance criteria and a criterion→test map the reviewer checks | Verifiable instead of advisory |
| Marker substring match | Body must *start* with the marker, author must be `claude[bot]` | No false triggers |
| Five workflows, three secrets | Three workflows + sweep, one secret | Less to maintain per repo |
| Tests assumed to run | Composite setup action extracted from CI; test command discovered from the repo and written into the plan | Claude can actually verify |
| No observability, no restart | Outcome comment on every phase; `status`, `reset`, `from`; weekly sweep | Issue timeline is the log; nothing is stranded |

Kept from v1: issue forms, spec and plan as issue comments plus a plan file in the PR, `claude[bot]` authoring via Action, my approval + `agent-approval-check` as the gate, public plugin repo, shared OAuth token, no third-party workflow plugins (templates borrowed from spec-kit and Superpowers; stage ideas from `softwareone-platform/issue-to-pr`).

## 15. Worked example: one issue, end to end

The timeline of issue #42 as it should read when everything works. This is also the fixture for testing the skills.

**Issue body (from the form)**

```
### Problem
Sessions time out after 15 minutes of inactivity but the UI shows no warning; users lose form input.

### Deliverables
(blank)

### Acceptance criteria
(blank)

### Out of scope
(blank)

### Notes
Related: #38
```

**Comment 1 (welcome.yml, github-actions)**: the §0 text and the §16 table.

**Comment 2 (me)**: `@claude go`

**Comment 3 (claude[bot], claude.yml)**: "This issue has no spec yet. Start a session in this repo and run `/go 42` (phone: claude.ai/code → New session → this repo). Next: `/go 42`."

*Design session (as me, interactive): two questions about deliverables, one about scope. Then:*

**Comment 4 (me, footer: written by Claude in a design session)**

```
<!-- go:spec v1 -->
## Spec
**Deliverables**: a warning banner 2 minutes before session expiry; a "stay signed in" action that extends the session.
**Acceptance criteria**
1. Given an idle session at T-2:00, expect the banner visible. Example: idle since 10:00:00 with 15-min timeout → banner at 10:13:00.
2. Given the banner, clicking "Stay signed in" resets the timer and hides the banner within 1s.
3. Given no click, at T-0 the session expires as today (no regression).
**Out of scope**: persisting unsaved form input; changing the timeout length.
**Blocked by**: none.
```

**Comment 5 (me, same footer)**

```
<!-- go:plan v1 -->
## Plan (spec v1)
Approach: client-side timer fed by the session's expires_at header; banner component; keepalive endpoint call.
Files: app/javascript/session_timer.js, app/views/layouts/_session_banner.html.erb, app/controllers/sessions_controller.rb, spec/system/session_timeout_spec.rb
Verification: `bundle exec rspec` · lint `bundle exec rubocop` · (from CLAUDE.md and .github/workflows/ci.yml)
Criterion → test: 1 → session_timeout_spec "shows banner two minutes before expiry"; 2 → "stay signed in extends the session"; 3 → "expires without interaction" (existing, must stay green)
Tasks:
1. [test first] system spec for criterion 1; implement timer + banner. Commit: "Add session expiry banner".
2. [test first] spec for criterion 2; add keepalive route + JS. Commit: "Add stay-signed-in keepalive".
3. Run full suite; confirm criterion 3's existing spec unchanged.
```

"Approve? Comment `@claude go` on the issue: <link>"

**Comment 6 (me)**: `@claude go`

**Comment 7 (claude[bot], claude.yml outcome step)**: "Implemented plan v1. Tests: 214 passed. Self-review: 2 findings fixed, clean. PR #43 opened. Run: <link>. Next: review PR #43; `@claude go` on the PR to fix anything."

*PR #43 (author claude[bot], body = spec summary + criterion→test map + link to `docs/plans/42-session-expiry-banner.md`). CI green.*

**PR comment (claude[bot], claude-review.yml)**

```
<!-- go:review pr=43 round=1 findings=1 -->
1 finding (Important): R1 — keepalive endpoint has no CSRF protection (app/controllers/sessions_controller.rb:31). Criterion→test map: 1 ✓ 2 ✓ 3 ✓.
```

**PR comment (claude[bot], claude.yml fix job)**: "Fixed R1 (added `protect_from_forgery` scope, spec added). Tests: 215 passed. Pushed. Next: review."

**PR comment (claude[bot], claude-review.yml)**: `<!-- go:review pr=43 round=2 findings=0 -->` "Clean. Review requested from @softwaregravy."

*I approve; agent-approval-check passes; I merge. Issue #42 closes.*

**Comment 8 (github-actions, sweep or claude.yml)**: "Merged in #43. Done." Label `claude:done`.

## 16. Naming table

Goes in the plugin README and in the welcome comment.

| Thing | Name / pattern | Where it appears |
|---|---|---|
| The command | `/go <n>` in sessions · `@claude go` on GitHub | everywhere |
| Subcommands | `/go <n> status` · `reset` · `from spec\|plan\|implement` | sessions only |
| Spec comment | starts `<!-- go:spec vN -->` | issue |
| Plan comment | starts `<!-- go:plan vN -->` | issue; copied to `docs/plans/<n>-<slug>.md` in the PR |
| Approval | my `@claude go` after a plan exists | issue |
| Review verdict | starts `<!-- go:review pr=N round=R findings=F -->` | PR |
| Outcome comment | last comment from `claude[bot]` after each run, with a run link | issue / PR |
| Branch | `claude/<n>-<slug>` | repo |
| PR body | "Closes #<n>" + spec summary + criterion→test map | PR |
| Labels (display only) | `claude:designing` · `implementing` · `pr-open` · `blocked` · `done` | issue |
| Design-session footer | `— written by Claude in a design session` | issue comments posted as me |
| Plugin | `workflow@softwaregravy` from `softwaregravy/claude-plugins` | everywhere |

## 17. Future improvements (preserve this section when revising)

v1 assumes **one user, me, alone and forgetful**. The items below were deliberately left out of v1 and should be reconsidered at the measurement checkpoint or when the assumption breaks. Do not delete this list; move items out only when built or explicitly rejected.

**`go` edge cases not handled in v1** (today: `go` says what it sees and stops):
- `/go` on a parent (feature) issue → should route to `feature-to-issues`.
- Spec revised after a PR is open → should flag the PR as stale and offer `from plan`.
- PR closed without merge → should treat as reset.
- Two open PRs for one issue → should ask which is live.
- Issue closed → should do nothing and say so.
- `@claude go` from a user without write access → the Action already ignores it; `go` should explain.
- `@claude go` twice while a run is in flight → `concurrency` queues it; `go` should say a run is already active.

**Failure handling per phase** (today: the `if: always()` step posts a generic outcome with a run link):
- Quota exhausted mid-run; runner timeout; setup composite fails; test command from the plan doesn't exist; `CLAUDE.md` missing. Each should post a specific message and a specific "Next:".

**Hardening**: pin the plugin to a tag; API key with spend cap instead of the shared OAuth token; treat issue text as hostile once anyone else can file issues; make `claude-review` a required check once its false-positive rate is known.

**Capability**: Projects as the design surface (paste the issue link); `claude:auto` to skip the approval comment for Claude-authored issues; ultrareview on large PRs; model per phase; post-merge decision records into `docs/decisions/`; persistent per-issue cloud session bridged by `claude -p … --cloud <id>`; multi-user (approval by someone other than the author, per-user attribution).

**Documentation home**: once `softwaregravy/claude-plugins` exists, this plan's §0, §5, §6, §16 move into its README and this file becomes a pointer plus the decisions log.

## 18. Sources

- https://code.claude.com/docs/en/github-actions and https://github.com/anthropics/claude-code-action (identity, inputs, `allowed_bots`, examples incl. `agent-approval-check`, `ci-failure-auto-fix`)
- https://code.claude.com/docs/en/claude-code-on-the-web, https://code.claude.com/docs/en/cloud-environments (what reaches cloud sessions)
- https://code.claude.com/docs/en/skills (frontmatter, `allowed-tools`, account-enabled skills in cloud sessions)
- https://code.claude.com/docs/en/plugins/loading, https://code.claude.com/docs/en/plugins/install
- https://code.claude.com/docs/en/code-review (`/code-review`, forked subagent), https://code.claude.com/docs/en/ultrareview
- https://code.claude.com/docs/en/claude-projects, https://code.claude.com/docs/en/feature-availability
- https://code.claude.com/docs/en/best-practices ("interview me", spec then fresh session, adversarial review subagent)
- Prior art: https://github.com/softwareone-platform/issue-to-pr, https://github.com/github/spec-kit, https://github.com/dsj1984/mandrel-platform/issues/434
