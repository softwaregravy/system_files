# Plan v2: Claude-driven issue → PR workflow

Status: agreed design, not yet built. v2 written 2026-09-28 after a critique of v1; §14 lists what changed and why. Facts about Claude Code surfaces were verified against the docs on 2026-09-27 (sources in §15).

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
- `.github/actions/setup/action.yml`: the composite that installs toolchain, deps, services. Used by `ci.yml` **and** the Claude jobs, so Claude runs tests in the same environment CI does
- `CLAUDE.md` must name: test, lint, typecheck commands (ideally one `bin/test`), branch and PR conventions
- Labels (display only): `claude:designing`, `claude:implementing`, `claude:pr-open`, `claude:blocked`, `claude:done`
- One secret: `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`; bills the Max subscription)
- Ruleset on `main`: require PR; required checks = CI, `claude-review`, `agent-approval-check`; 1 approval; no force-push

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

3. Do the step. 4. Post one comment: what it did, outcome, link to the run or session. 5. Set the display label. 6. End with "Next: …".

`/go 42 status` does steps 1–2 and prints. `/go 42 reset` and `from <phase>` are in §11.

## 6. Spec and plan templates

Headings are fixed so the form, `feature-to-issues`, and the skills agree.

**Issue form (`task.yml`)** — Problem (required); Deliverables, Acceptance criteria, Out of scope, Notes (optional). Blank optional sections are what `go-plan` interviews about. `config.yml` leaves blank issues enabled for notes not meant for Claude.

**Spec rules** (`templates/spec.md`), enforced by `go-plan`:

- Every acceptance criterion is a check someone could run: *given X, expect Y*, with at least one concrete example.
- Out-of-scope is explicit, even if "none".
- Dependencies: "blocked by #N" in Notes.
- The spec is posted as one comment starting with `<!-- go:spec v1 -->`; revisions post a new comment with a bumped version.

**Plan rules** (`templates/plan.md`):

- Header: goal, approach, files touched, spec version it implements.
- **Criterion → test map** before any task: each acceptance criterion names the test that verifies it.
- Tasks in order, each with exact file paths, the test to write first, the verification command, and a commit message. Small enough that one task is one commit.
- Posted as one comment starting with `<!-- go:plan v1 -->`; copied into the PR as `docs/plans/<n>-<slug>.md`.

Claude-authored issues (from `feature-to-issues`) arrive with the spec sections filled and `### Parent` linking the feature issue, so `go` skips straight to planning.

## 7. Phases

### Phase 1: design (my session)

Trigger: I run `/go 42` in a session, or `@claude go` on an issue without a spec makes the Action reply "Start a session in this repo and run `/go 42`" (from a phone: claude.ai/code → new session in the repo). No session is created from GitHub.

`go-plan`: read issue and parent → subagents explore the codebase → interview me with `AskUserQuestion` only about blank sections → post spec → pre-mortem (risks, edge cases, what tests would miss) → write plan → post plan → "Approve?" If yes, I'm asked to comment `@claude go` on the issue (a clickable link is posted). The session never flips state on my behalf; approval is always my comment.

### Phase 2: implement (Action, `claude[bot]`)

Trigger: `@claude go` on an issue with a plan and no open PR. `claude.yml` runs the composite setup, then `claude-code-action` with `prompt: "/go 42"`.

`go-implement`:
1. Refuse if a blocker issue is open or the plan's spec version is stale (spec revised after plan).
2. Branch `claude/42-<slug>` from current `main`; commit the plan file.
3. For each task: write the test, implement, run `bin/test` locally in the runner. Many local runs, no CI runs.
4. Self-review loop: run `/code-review` in a forked subagent (fresh context) against the diff and the plan's criterion→test map; fix; re-run tests; repeat until the review is clean.
5. Blocked → comment the question on the issue, label `claude:blocked`, stop.
6. `gh pr create` with "Closes #42", body = spec summary, criterion→test map, link to plan. Comment the PR link on the issue.

Push count: one, when the PR opens. CI runs once.

### Phase 3: PR review (Action, `claude[bot]`)

Trigger: `pull_request` opened / synchronize / ready_for_review, same-repo branches only. `claude-review.yml` → `go-review`.

- Inline findings with stable IDs and severities. First pass is the criterion→test map: a criterion without a passing test is Important.
- Verdict comment whose body **starts with** `<!-- go:review pr=123 round=2 findings=3 -->`. Also written as the `claude-review` check conclusion (required status).
- Convergence rules: round 2+ reports Important and regressions only; never reopens an ID resolved with a "won't fix: reason"; if the same ID survives two rounds, stop and request my review instead of another round.

### Phase 4: fix (Action, `claude[bot]`)

Trigger, in `claude.yml`: `issue_comment` on a PR whose body starts with the review marker and author is `claude[bot]` (`allowed_bots: claude[bot]`), with `findings > 0`; or `workflow_run` of CI concluded failure on a same-repo PR; or `@claude go` on the PR.

`go-fix`: merge `main` into the branch first (never rebase or force-push; my commits are kept) → address each finding or the CI failure → reply on each thread (fixed, or won't fix with reason, and resolve) → `bin/test` locally → push once. The push re-runs review and CI.

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

`claude-review.yml`: `pull_request` events → setup → `claude-code-action` with `prompt: "/go <pr>"` and review-only tools; writes the `claude-review` check.

`agent-approval-check.yml`: Anthropic's example, `required_approvals: 1`, `agent_logins: claude[bot]`.

`sweep.yml`: weekly cron, no Claude: delete `claude/*` branches with no open PR older than 14 days; comment on issues with a `claude:*` label and no activity for 14 days; label merged-PR issues `claude:done`.

Reads to keep in mind: `issue_comment` fires for PR comments too (the `issue.pull_request` guard sorts them); an `if: always()` final step reports every outcome; `cancel-in-progress: false` so a fix never cancels a running implement.

## 9. Efficiency

- Self-review inside the implementation job means the typical issue is 3 Action runs (implement, one review, occasionally one fix) instead of 8. Warm cache and no runner boots between rounds.
- Local `bin/test` inside the runner is the inner loop; CI runs once per push; pushes happen once per phase.
- `--model` per phase in `claude_args`: strongest model for plan and implement; a cheaper one for review and fix (tune after observing).
- `CLAUDE.md` stays short (loaded every run). Procedure lives in skills, loaded on demand.
- Public repos have free Actions minutes; private repos have a monthly allowance. Check per repo.

## 10. Permissions

- Per-job GitHub `permissions:` with only what that job writes (review job: `contents: read`, `pull-requests: write`).
- `--allowedTools` is an explicit list, the same in the skill's `allowed-tools` frontmatter, so nothing runs in CI that can't run locally:
  - implement/fix: `Edit, Write, Read, Glob, Grep, Bash(bin/test:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git checkout:*), Bash(git merge:*), Bash(gh pr create:*), Bash(gh pr view:*), Bash(gh pr comment:*), Bash(gh issue view:*), Bash(gh issue comment:*), Bash(gh issue edit:*)` plus the repo's lint/typecheck commands from `CLAUDE.md`
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

1. `@claude go` on a spec-less issue gets the "start a session" reply; `/go 42` in a cloud session and in the terminal both run the interview and post spec + plan.
2. `@claude go` after the plan starts `claude.yml`; the composite setup gives Claude a working `bin/test`.
3. Self-review loop runs in-job and the PR opens with `claude[bot]` as author.
4. `claude-review.yml` posts findings and the verdict; its check shows as required.
5. A `findings>0` verdict triggers the fix job; a `findings=0` verdict does not; my `@claude go` on the PR does.
6. `agent-approval-check` blocks merge until I approve; approve + merge closes the issue.
7. `/go 42 status`, `/go 42 reset`, and the `if: always()` outcome comment behave.

## 13. Rollout

1. **Plugin repo + `go`, `go-plan`, templates.** Test `/go` locally against a real issue in `system_files`. No Actions yet.
2. **Bootstrap one repo:** form, labels, composite setup, `claude.yml` (implement only), token, ruleset, `agent-approval-check`. Verify 1–3, 6.
3. **Review:** `go-review`, `claude-review.yml`. Verify 4. Fix by hand or with `@claude go` on the PR.
4. **Automatic fix:** enable the verdict and CI triggers. Verify 5, 7. Add `sweep.yml`.
5. **Front end and second repo:** `feature-to-issues`, `init-repo`.
6. **Later:** pin the plugin to a tag (supply chain); Projects as the design surface; `claude:auto` to skip the approval comment for Claude-authored issues; ultrareview on large PRs; API key with spend cap if quota sharing bites; post-merge decision records.

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
| Tests assumed to run | Composite setup action shared with CI; `bin/test` as the inner loop | Claude can actually verify |
| No observability, no restart | Outcome comment on every phase; `status`, `reset`, `from`; weekly sweep | Issue timeline is the log; nothing is stranded |

Kept from v1: issue forms, spec and plan as issue comments plus a plan file in the PR, `claude[bot]` authoring via Action, my approval + `agent-approval-check` as the gate, public plugin repo, shared OAuth token, no third-party workflow plugins (templates borrowed from spec-kit and Superpowers; stage ideas from `softwareone-platform/issue-to-pr`).

## 15. Sources

- https://code.claude.com/docs/en/github-actions and https://github.com/anthropics/claude-code-action (identity, inputs, `allowed_bots`, examples incl. `agent-approval-check`, `ci-failure-auto-fix`)
- https://code.claude.com/docs/en/claude-code-on-the-web, https://code.claude.com/docs/en/cloud-environments (what reaches cloud sessions)
- https://code.claude.com/docs/en/skills (frontmatter, `allowed-tools`, account-enabled skills in cloud sessions)
- https://code.claude.com/docs/en/plugins/loading, https://code.claude.com/docs/en/plugins/install
- https://code.claude.com/docs/en/code-review (`/code-review`, forked subagent), https://code.claude.com/docs/en/ultrareview
- https://code.claude.com/docs/en/claude-projects, https://code.claude.com/docs/en/feature-availability
- https://code.claude.com/docs/en/best-practices ("interview me", spec then fresh session, adversarial review subagent)
- Prior art: https://github.com/softwareone-platform/issue-to-pr, https://github.com/github/spec-kit, https://github.com/dsj1984/mandrel-platform/issues/434
