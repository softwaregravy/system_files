# Plan: Claude-driven issue → PR workflow

Status: agreed design, not yet built. Written 2026-09-28 from a planning session; facts about Claude Code surfaces were verified against the docs on that date (sources at the end).

## 1. Goal

Work is planned with Claude, recorded as GitHub issues, and executed one issue at a time without opening and driving a session by hand:

1. An issue exists (written by me, quickly, or by Claude from a higher-level feature session).
2. Before any code: the deliverables and acceptance criteria are clear and an implementation plan is agreed.
3. Claude implements, tests, and opens a PR.
4. Claude reviews the PR and fixes what it finds, in a loop, until the review is clean and CI is green.
5. I read, approve, merge.

Personal conventions (the skills, templates, and workflows) live in one shared place and work identically across repos and across every Claude surface (terminal, cloud session, GitHub Action).

## 2. Design principles

- **The issue is the only shared state.** Every phase reads its inputs from the issue and writes its outputs back to it. Labels are the state machine. Any phase can be swapped for a different surface later without touching the others.
- **Thinking wants persistence; executing wants a clean slate.** The design conversation runs in one persistent, interactive session (no lost context, warm cache). Implementation and review run fresh, from a fully written spec and plan.
- **Claude authors, I review.** Anything that writes code or opens a PR runs as `claude[bot]` (GitHub Action). GitHub then treats me as a distinct reviewer, so I can approve.
- **Repo files carry facts; the plugin carries procedure.** `CLAUDE.md` says how this repo builds and tests. The plugin says how an issue becomes a PR. Neither references the other.
- **Deterministic stops.** Round caps, `--max-turns`, workflow timeouts, and labels decide when a loop ends. "Looks done" is never the signal.

## 3. Architecture

```
                 ┌──────────────────────────────────────────────────────────────┐
                 │ GitHub issue  (form-templated; labels = state machine)        │
                 └──────────────────────────────────────────────────────────────┘
   "@claude go"        │ no approved plan                       │ label claude:go
   or auto-label       ▼                                        ▼
   ┌─────────────────────────────────┐          ┌─────────────────────────────────┐
   │ Action: claude-go.yml           │          │ Action: claude-implement.yml     │
   │ POST routine /fire → session URL│          │ claude-code-action as claude[bot]│
   │ comment link on issue           │          │ /implement-issue N → PR          │
   └─────────────────────────────────┘          └─────────────────────────────────┘
                 │                                               │ PR opened / synchronize
                 ▼                                               ▼
   ┌─────────────────────────────────┐          ┌─────────────────────────────────┐
   │ Cloud session (Anthropic VM,    │          │ Action: claude-review.yml        │
   │ acts as me) /plan-issue N       │          │ /review-pr → inline findings +   │
   │ interview → spec → plan →       │          │ verdict comment (marker)         │
   │ approve? → flips label claude:go│          └─────────────────────────────────┘
   └─────────────────────────────────┘                          │ verdict has findings
                                                                ▼
                                                ┌─────────────────────────────────┐
                                                │ Action: claude-fix.yml           │
                                                │ (allowed_bots: claude[bot])      │
                                                │ /fix-pr → push → re-review       │
                                                │ also: workflow_run failure → fix │
                                                └─────────────────────────────────┘
                                                                │ clean + CI green
                                                                ▼
                                                   me: approve → merge → issue closes
```

Two clicks from me in the happy path: the design-session link, and Approve.

## 4. Components

### 4.1 `softwaregravy/claude-plugins` (new, public repo)

A plugin marketplace (`.claude-plugin/marketplace.json`) with one plugin, `workflow`. Public so the GitHub Action can fetch it without extra credentials.

```
claude-plugins/
├── .claude-plugin/marketplace.json
└── plugins/workflow/
    ├── .claude-plugin/plugin.json
    ├── skills/
    │   ├── plan-issue/SKILL.md          # design session: interview → spec → plan → gate
    │   ├── implement-issue/SKILL.md     # fresh run: plan → code → tests → PR
    │   ├── review-pr/SKILL.md           # findings + verdict marker
    │   ├── fix-pr/SKILL.md              # address findings / CI, reply on threads, push
    │   ├── feature-to-issues/SKILL.md   # big-picture session → templated issues
    │   └── init-repo/SKILL.md           # copy per-repo bootstrap into a repo
    ├── templates/
    │   ├── spec.md                      # section headings shared by form, skills, feature session
    │   ├── plan.md                      # task list format (borrowed from spec-kit / Superpowers)
    │   ├── ISSUE_TEMPLATE/task.yml      # issue form
    │   ├── ISSUE_TEMPLATE/task-go.yml   # same form, auto-applies claude:go
    │   ├── ISSUE_TEMPLATE/config.yml
    │   └── workflows/*.yml              # the five workflows below
    └── README.md
```

Distribution:

| Surface | How the skills get there |
|---|---|
| Local terminal | `/plugin marketplace add softwaregravy/claude-plugins` then `/plugin install workflow@softwaregravy-claude-plugins` (marketplace `name` TBD in `marketplace.json`) |
| GitHub Action | `plugin_marketplaces: https://github.com/softwaregravy/claude-plugins.git` + `plugins: workflow@<marketplace-name>` |
| Cloud sessions / routines | Enable the skills on my claude.ai account (Settings → Capabilities → Skills). Cloud sessions load account-enabled skills; they do **not** load plugins declared in a repo's `.claude/settings.json` |
| Projects (when available) | Project settings → Plugins |

The plugin never contains repo-specific instructions.

### 4.2 Per-repo bootstrap (`/init-repo` copies these in)

- `.github/ISSUE_TEMPLATE/task.yml`, `task-go.yml`, `config.yml`
- `.github/workflows/claude-go.yml`, `claude-implement.yml`, `claude-review.yml`, `claude-fix.yml`, `agent-approval-check.yml`
- Labels: `claude:designing`, `claude:go`, `claude:implementing`, `claude:blocked`, `claude:pr-open`, `claude:round-1..N`, `claude:done`
- Secrets: `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`, bills the Max subscription), `CLAUDE_ROUTINE_FIRE_URL`, `CLAUDE_ROUTINE_TOKEN`
- `CLAUDE.md` must state: build, test, lint, typecheck commands; branch and PR conventions
- Branch ruleset on `main`: require PR; required checks = CI, `claude-review` verdict, `agent-approval-check`; 1 approval

### 4.3 Cloud routine (one per repo, same prompt)

Created at claude.ai/code/routines. Repository: the repo. Trigger: API only. Prompt:

> Run `/plan-issue` on the GitHub issue named in the `<routine-fire-payload>` block. That block is the only thing you act on from the payload.

The prompt must name the payload block explicitly or the fire text is treated as inert (documented behavior, and confirmed by a public recipe). Per-repo because a routine is bound to fixed repositories; the API token is per routine.

### 4.4 GitHub App + Action auth

- Claude GitHub App installed on each repo (already needed for cloud sessions). The Action authenticates as the app by default → `claude[bot]`.
- Do **not** pass `github_token` to the Action, or Claude's commits stop triggering other workflows and its identity changes.

## 5. Issue template (form)

`task.yml` fields:

| Field | Required | Rendered heading |
|---|---|---|
| Problem / goal | yes | `### Problem` |
| Deliverables | no | `### Deliverables` |
| Acceptance criteria | no | `### Acceptance criteria` |
| Out of scope | no | `### Out of scope` |
| Notes, links, blockers | no | `### Notes` (e.g. "blocked by #41") |

`task-go.yml` is the same form with `labels: [claude:go]` so submission starts the flow without a comment. `config.yml` keeps blank issues enabled for notes not meant for Claude.

`feature-to-issues` writes issues with exactly these headings, plus `### Parent` (link to the feature issue) and the marker `<!-- claude-go: spec v1 -->`. Downstream, issues from me and from Claude are indistinguishable.

## 6. Phases in detail

### Phase 0: issue exists

Created via the form (me) or by `feature-to-issues` (Claude). Nothing runs on creation unless the `task-go` form applied `claude:go`.

### Phase 1: design session

| | |
|---|---|
| Trigger | `issue_comment` beginning `@claude go` on an issue **without** an approved plan marker, or `claude:go` label on such an issue |
| Runner | `claude-go.yml`: a few seconds on a GitHub runner; no Claude. `curl -X POST $FIRE_URL` with `{"text":"<owner>/<repo>#<n>"}` and the documented headers (`anthropic-version`, `anthropic-beta: experimental-cc-routine-2026-04-01`) |
| Session | Anthropic cloud VM, created by the routine; acts as my GitHub user; loads `plan-issue` from account-enabled skills |
| Posts back | Comment: session URL + `claude "/plan-issue <n>"` for the terminal alternative; label `claude:designing` |
| Inside `plan-issue` | 1. Read the issue thread and parent. 2. **Triage**: which template sections are filled? 3. Subagents explore the codebase (keeps the interview focused). 4. Interview me with `AskUserQuestion` only about the blank sections. 5. Post the spec (`<!-- claude-go: spec vN -->`). 6. Pre-mortem the spec (risks, edge cases). 7. Write the plan in the plan template; post it (`<!-- claude-go: plan vN -->`). 8. Ask "approve?" |
| Exit | On yes: label `claude:go` (the actor is me, so the Action's write-access check passes). On no: revise and re-ask. If I leave, the session idles at the question at no cost |
| Terminal path | Same skill run locally in plan mode; ends the same way. Teleport (`claude --teleport <session>`) also works |

Triage outcomes: free-form issue → full interview; spec present, no plan → skip interview, write plan, approve; spec and plan present → one-click approve. A later `claude:auto` label could skip the gate for Claude-authored issues; off until the flow has been observed.

### Phase 2: implementation

| | |
|---|---|
| Trigger | `issues: [labeled]` with `claude:go` and a plan marker present |
| Runner | `claude-implement.yml`: `claude-code-action`, automation mode, `prompt: "/implement-issue <n>"`, plugin inputs, `claude_args: --max-turns 80 --allowedTools "Edit,Write,Read,Glob,Grep,Bash(git:*),Bash(gh:*),Bash(<test/lint cmds>)"`, `timeout-minutes`, `concurrency: issue-<n>` |
| Identity | `claude[bot]` |
| Inside `implement-issue` | Refuse if any "blocked by" issue is open. Branch `claude/<n>-<slug>`. Copy the plan to `docs/plans/<n>-<slug>.md`. Implement task by task; write and run tests; lint/typecheck per `CLAUDE.md`; verify the acceptance criteria. Blocked → comment the question on the issue, label `claude:blocked`, stop |
| Exit | `gh pr create` with "Closes #<n>", body = spec summary + plan link; comment PR link on the issue; label `claude:pr-open` |

Fresh context is deliberate here: the plan format exists so a reader with no memory of the design conversation can execute it.

### Phase 3: review-and-fix loop

| | |
|---|---|
| Reviewer | `claude-review.yml` on `pull_request: [opened, synchronize, ready_for_review]`, `prompt: "/review-pr <pr>"`, allowed tools: inline-comment MCP tool, `gh pr view/diff/comment`. Posts severity-tagged inline findings and one verdict comment with a marker (`<!-- claude-review: findings=3 round=1 -->` or `findings=0`). Reviews plan-vs-diff as well as correctness |
| Fixer | `claude-fix.yml` on `issue_comment` where the body has the review marker with `findings>0`, `allowed_bots: claude[bot]`, `prompt: "/fix-pr <pr>"`. Fixes, replies on each thread, resolves what it fixed, pushes → `synchronize` → reviewer runs again. Increments `claude:round-N` |
| CI red | Same `fix-pr` skill triggered by `workflow_run` (conclusion failure, same-repo PR), per Anthropic's `ci-failure-auto-fix` example, but pushing to the PR branch rather than a side branch |
| Stop | `findings=0` and CI green → comment "ready for human review" on PR and issue, request my review. Round cap (default 3) → comment what is still open and stop. Never skip or disable a test to get green |

Known gotcha: Anthropic's `code-review` plugin skips PRs that already have a Claude comment, so `review-pr` is our own skill (it may call `/code-review` internally for the bug hunt).

### Phase 4: me

Read the PR (plan file is in the diff, so plan-vs-implementation is reviewable), approve, merge. `agent-approval-check` (required status) blocks merge of `claude[bot]` commits without a human approval. Merge closes the issue; label `claude:done`. Optional later: a post-merge step that appends a decision record to `docs/decisions/`.

### Phase -1: feature session (optional front end)

A local, cloud, or Projects session runs `feature-to-issues`: big-picture interview once, then decomposes into templated issues with dependencies ("blocked by") and parent links. Nothing auto-starts; I label or comment when ready, which keeps ordering in my hands.

## 7. Label state machine

```
(none) ──@claude go / claude:go──▶ claude:designing ──approve──▶ claude:go
claude:go ──Action starts──▶ claude:implementing ──PR──▶ claude:pr-open
claude:implementing ──question──▶ claude:blocked ──answer + re-label──▶ claude:go
claude:pr-open ──loop rounds──▶ claude:round-N ──clean + green──▶ (review requested)
merge ──▶ claude:done
```

Exactly one `claude:*` phase label at a time; the round label is additive.

## 8. Skills: responsibilities

| Skill | Runs in | Reads | Writes | Must never |
|---|---|---|---|---|
| `plan-issue` | cloud session / terminal (interactive) | issue, parent, codebase | spec + plan comments, labels | write code |
| `implement-issue` | Action (fresh) | spec, plan, `CLAUDE.md` | branch, `docs/plans/<n>.md`, PR, issue comment | start with open blockers; open a PR with failing tests |
| `review-pr` | Action | PR diff, plan file, `CLAUDE.md` | inline findings, verdict comment | approve or block (it can't anyway) |
| `fix-pr` | Action | findings / CI logs | commits, thread replies | skip/disable tests; exceed round cap |
| `feature-to-issues` | any interactive | conversation, codebase | templated issues with deps | start work |
| `init-repo` | terminal | plugin templates | repo files, labels, instructions for secrets/routine | commit secrets |

Skill frontmatter: `disable-model-invocation: true` on everything with side effects; `allowed-tools` scoped per skill; `$ARGUMENTS` = issue or PR number. Shared templates referenced via `${CLAUDE_SKILL_DIR}/../../templates/`.

## 9. Workflow sketches

`claude-go.yml`:

```yaml
on:
  issue_comment: { types: [created] }
  issues: { types: [labeled] }
jobs:
  fire:
    if: >-
      (github.event_name == 'issue_comment' && !github.event.issue.pull_request
        && startsWith(github.event.comment.body, '@claude go'))
      || (github.event_name == 'issues' && github.event.label.name == 'claude:go')
    runs-on: ubuntu-latest
    permissions: { issues: write }
    steps:
      - id: state   # has an approved plan marker? then this event belongs to claude-implement.yml
        run: gh issue view "$N" --json body,comments -q '…' …
      - if: steps.state.outputs.has_plan == 'false'
        run: |
          RESP=$(curl -sS -X POST "$FIRE_URL" \
            -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
            -H "anthropic-version: 2023-06-01" \
            -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
            -d "{\"text\":\"${{ github.repository }}#$N\"}")
          URL=$(jq -r .claude_code_session_url <<<"$RESP")
          gh issue comment "$N" --body "🧠 Design session: $URL …"
          gh issue edit "$N" --add-label claude:designing --remove-label claude:go
```

`claude-implement.yml`, `claude-review.yml`, `claude-fix.yml`: `anthropics/claude-code-action@v1` with `claude_code_oauth_token`, `plugin_marketplaces`, `plugins`, a `prompt` invoking the skill, `claude_args` with `--max-turns` and a tight `--allowedTools`, `concurrency` per issue/PR, `timeout-minutes`. `claude-fix.yml` adds `allowed_bots: claude[bot]`. `agent-approval-check.yml` is Anthropic's example with `required_approvals: 1`.

## 10. Costs and limits

- Action runs: GitHub Actions minutes + Max subscription usage via the OAuth token. Every phase is a cold run; keep prompts tight and `CLAUDE.md` short.
- Design session: subscription usage; idles free while waiting on me. Routine fires count against the daily routine-run cap.
- No managed Code Review on Max (Team/Enterprise only). `/code-review ultra` is available for big PRs: 3 free runs, then $5–25 in usage credits each; not wired into the loop by default.
- The `/fire` endpoint is research preview behind a dated beta header; pin the header and expect to bump it.

## 11. Verify on the first real run

1. `/fire` from the Action returns the session URL and the session receives the payload (prompt names the block).
2. A routine-started session pauses on `AskUserQuestion` and resumes when I answer later.
3. The session's label flip (as me) triggers `claude-implement.yml`.
4. With `gh pr create` allowed, the PR author is `claude[bot]`.
5. A `claude[bot]` verdict comment triggers `claude-fix.yml` with `allowed_bots` set, and its push re-triggers `claude-review.yml`.
6. The round cap and `concurrency` actually stop the loop.
7. Account-enabled skills load in the cloud session; plugin skills load in the Action.

## 12. Rollout

1. **Plugin repo**: marketplace + `plan-issue` + templates. Test `plan-issue` locally against a real issue in `system_files`.
2. **Bootstrap one repo**: issue forms, labels, `claude-go.yml`, routine + secrets. Verify items 1–3.
3. **Implementation**: `implement-issue` + `claude-implement.yml`. Verify item 4. Ruleset + `agent-approval-check`.
4. **Loop**: `review-pr`, `fix-pr`, `claude-review.yml`, `claude-fix.yml`, CI-failure trigger. Verify 5–6.
5. **Front end**: `feature-to-issues`, `init-repo`; roll out to a second repo with `/init-repo`.
6. **Later options**: `claude:auto` for Claude-authored issues; cloud Auto-fix or Projects threads as an inspectable alternative fixer; persistent per-issue session bridged by `claude -p … --cloud <id>`; post-merge decision records; ultrareview on large PRs.

## 13. Decisions log

| Decision | Choice | Why |
|---|---|---|
| Plan tier | Max | Sets what's available: no managed Code Review; Projects when rolled out |
| System of record | GitHub issue + labels | Every surface reads/writes it; independent of betas |
| Where the plan lives | Issue comment (approved) + file in the PR | Reviewable with the code; durable in history |
| Design conversation | Persistent interactive cloud session (or terminal), not per-comment Action runs | Keeps unwritten context and cache; per-comment runs re-explore and cost more |
| Execution/review identity | `claude[bot]` via GitHub Action | I can approve; `agent-approval-check` enforces it |
| Trigger | `@claude go` comment, or `claude:go` via the `task-go` form | Explicit; works from a phone |
| Human gate | Required approval + `agent-approval-check` + required checks | Yes to all |
| Skills repo | Public `softwaregravy/claude-plugins` | Action can fetch it without credentials |
| Superpowers / feature-dev / spec-kit | Not dependencies; borrow templates and stage ideas | Terminal-shaped, opinionated, extra context cost; we need issue-centric behavior |
| Sortie / daemons | Not used | Actions + cloud sessions cover it without hosting anything |
| Issue authoring | GitHub issue form; optional fields | I can file thin issues without loading Claude; Claude-written issues use the same headings |

## 14. Prior art reviewed

- Anthropic `claude-code-action` (+ examples `issue-triage`, `ci-failure-auto-fix`, `pr-review-comprehensive`, `agent-approval-check`) — used directly.
- `dsj1984/mandrel-platform#434` — recipe for firing a routine from a workflow; reports routines' native GitHub triggers never fired for them.
- `softwareone-platform/issue-to-pr` — local 11-stage pipeline with a plan-approval gate and adversarial reviewers; borrowed fact-check and pre-mortem stages.
- `github/spec-kit` — spec/plan templates; `taskstoissues`.
- `SiddaharthSuman/spec-driven-dev` — same mechanism-vs-project-rules split.
- Sortie, `ableinc/coding-agent-loop`, GitHub Copilot coding agent — label-to-PR orchestration comparables.

## 15. Sources

- https://code.claude.com/docs/en/claude-code-on-the-web
- https://code.claude.com/docs/en/cloud-environments (what carries over into cloud sessions)
- https://code.claude.com/docs/en/routines (API trigger, payload wrapping, PR/release-only GitHub triggers)
- https://code.claude.com/docs/en/github-actions and https://github.com/anthropics/claude-code-action (identity, inputs, examples)
- https://code.claude.com/docs/en/claude-projects
- https://code.claude.com/docs/en/code-review, https://code.claude.com/docs/en/ultrareview
- https://code.claude.com/docs/en/plugins/loading, https://code.claude.com/docs/en/plugins/install, https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/feature-availability
- https://code.claude.com/docs/en/best-practices, https://code.claude.com/docs/en/memory
