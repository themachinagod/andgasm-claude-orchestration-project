---
name: orchestrate
description: >
  Pipeline orchestrator. Reads project state, determines the pipeline stage
  and sub-state for open issues, and dispatches the appropriate agent team.
  Automatically bridges Discovery to Review by detecting unsubmitted PRDs
  and creating the branch, PR, and issue without requiring /submit-prds.
  Handles review, decompose, and design stages. Designed to be called by
  ralph.sh for autonomous operation or interactively by the user.
---

## Instructions

### Workspace Model

You operate from a workspace root that contains the docs repo as a
subdirectory. All content is accessible from workspace root — use `cd`
only for git operations within specific repos.

```
workspace/
├── .claude/                  ← agents, skills, hooks, rules
├── CLAUDE.md                 ← operating manual
├── [DOCS_REPO]/              ← docs, status, coordination (git repo)
│   ├── STATUS.md
│   ├── repos.yaml
│   ├── active-work/
│   └── docs/
```

The `[DOCS_REPO]` path is defined in `CLAUDE.md` under "Workspace Layout".

### Phase 1: Orient

1. Note your session ID from the startup hook output (interactive) or
   prompt (Ralph). Read `[DOCS_REPO]/STATUS.md` — check Active Sessions
   for stale entries (>4 hours) and for entries from YOUR session ID
   (should not exist yet — if they do, a prior instance crashed without
   cleanup). Review Watch Items for context, In Flight and Blocked for
   current work state.
2. Read `[DOCS_REPO]/repos.yaml` — understand repo topology
3. Check for open pipeline issues across all stages:
   ```bash
   cd [DOCS_REPO]
   gh issue list --state open \
     --json number,title,labels,body \
     --jq '.[] | select(.labels[].name | startswith("pipeline:"))'
   ```
4. If no pipeline issues exist, check for unsubmitted PRDs:
   ```bash
   # Still inside [DOCS_REPO] from step 3
   ls docs/prd/*.md 2>/dev/null | grep -v templates/
   ```
   - If PRD files exist (outside `templates/`), check whether they've
     already been submitted:
     ```bash
     gh issue list --label "type:prd-review" --state all --json number,title
     ```
     Also check for new/modified PRD files not yet committed or not yet
     on a submission branch:
     ```bash
     git status --porcelain docs/prd/ docs/discovery/
     ```
     **Submit only if:** there are uncommitted/untracked PRD files, OR
     no `type:prd-review` issues exist at all (first submission ever).
     If all PRDs are committed, at least one `type:prd-review` issue
     exists (open or closed), and there are no new changes — these PRDs
     have already been submitted. Do not re-submit.
   - If PRDs need submitting: this is the Discovery → Review transition.
     Run the submit-prds logic (see **Stage: Unsubmitted PRDs** below)
     to create the branch, PR, and `pipeline:review` issue, then continue
     orchestration with the newly created issue.
   - If no PRD files exist, or all PRDs already submitted:
     - Report: "No open pipeline issues and no PRDs to submit. Nothing to orchestrate."
     - Update STATUS.md if needed
     - `cd ..` and stop
5. For each pipeline issue, read the latest state comment to determine sub-state:
   ```bash
   gh issue view [NUMBER] --json comments --jq '[.comments[] | select(.body | contains("**Status:**"))] | last | .body'
   ```
   The orchestrator detects state by finding the latest issue comment
   containing `**Status:**` and reading the text after it. If no comment
   contains `**Status:**`, the issue is in its initial sub-state.
6. Check for associated PR:
   ```bash
   gh pr list --json number,title,headRefName,body \
     | jq '.[] | select(.body | contains("#[ISSUE_NUMBER]"))'
   ```
7. `cd ..` to return to workspace root

### Phase 2: Decide

Determine which pipeline stage to handle based on priority:

0. Unsubmitted PRDs — detected in Orient, handled before any pipeline issues
1. `pipeline:review` — review and facilitation cycle
2. `pipeline:decompose` — PRDs → epics + roadmap
3. `pipeline:design` — epic-level design + task decomposition
4. `pipeline:implement` — per-task coding + specialist PR review
5. Any other `pipeline:*` — report "not yet implemented" and stop

If multiple issues exist, handle the highest-priority one. Priority
follows the orchestration priority in `.claude/rules/pipeline.md`.

Skip rules:
- `blocked` label → skip until blocker resolved
- `needs-stakeholder-input` → if interactive (session ID starts with
  `interactive-`): can handle. If Ralph (session ID starts with
  `ralph-`): stop.
- `claimed:*` label with a DIFFERENT session ID → skip, another session
  is working on this. If the claimed label matches YOUR session ID, a
  prior instance crashed — remove the stale claim and treat as unclaimed.

### Phase 3: Execute

Based on the pipeline stage, dispatch the appropriate logic:

---

#### Stage: `pipeline:review`

Read the latest issue comment to determine the review sub-state:

| What you see | Sub-state | Next action |
|-------------|-----------|-------------|
| No `**Status:**` comment from agents | **Needs first review** | Invoke Review Team |
| `**Status:** Reviewed, [N] items need stakeholder input` | **Needs stakeholder input** | Check if interactive, invoke Facilitator or stop |
| `**Status:** stakeholder input provided, ready for re-review` | **Needs re-review** | Invoke Review Team |
| `**Status:** Approved` | **Approved** | Check CI, merge PR, advance label |
| `needs-stakeholder-input` label present | **Waiting for user** | Stop (Ralph) or invoke Facilitator (interactive) |

##### Sub-state: Needs First Review / Needs Re-Review

Invoke the review team — product-manager and architect as sub-agents.

**Step 1: Product Review**

Delegate to the `product-manager` sub-agent with this context:
- "You are part of the review team for PRD submission #[NNN]."
- "Review ALL PRDs on PR #[PR_NUMBER] for product completeness, consistency,
  and cross-PRD conflicts."
- "Fix obvious issues directly (push to PR branch)."
- "Leave PR comments for items needing stakeholder input."
- "When done, report back with: number of items auto-fixed, number needing
  stakeholder input, and overall readiness assessment."

```bash
cd [DOCS_REPO]
git checkout [pr-branch]
git pull origin [pr-branch]
```

The product-manager reads all PRDs and discovery docs, reviews, and pushes
any fixes to the branch. It leaves PR review comments for stakeholder items.

```bash
cd ..
```

**Step 2: Technical Review**

Delegate to the `architect` sub-agent with this context:
- "You are part of the review team for PRD submission #[NNN]."
- "Review ALL PRDs on PR #[PR_NUMBER] for technical feasibility."
- "Assess: can each PRD be built? Are NFRs realistic? Hidden complexity?
  Integration risks? Dependency ordering?"
- "Fix obvious technical inaccuracies (push to PR branch)."
- "Leave PR comments for items needing stakeholder input."
- "When done, report back with: technical feasibility per PRD, risks,
  and items needing stakeholder input."

**Step 3: Synthesize and Update Issue**

After both agents report back, synthesize their findings:

```bash
cd [DOCS_REPO]
```

If items need stakeholder input:

```bash
gh issue comment [NUMBER] --body "## Review Team — Cycle [N]

**Product review:** [summary from product-manager]
**Technical review:** [summary from architect]

**Auto-fixed:** [N] items (formatting, consistency, minor gaps)
**Needs stakeholder input:** [N] items

### Items for stakeholder discussion:
1. [Item from product review — brief description]
2. [Item from technical review — brief description]
...

**Status:** Reviewed, [N] items need stakeholder input."

gh issue edit [NUMBER] --add-label "needs-stakeholder-input"
```

If everything is clean (no items need stakeholder input):

```bash
gh issue comment [NUMBER] --body "## Review Team — Cycle [N]

**Product review:** All PRDs meet quality bar.
**Technical review:** All PRDs are technically feasible.

**Auto-fixed:** [N] items
**Needs stakeholder input:** 0

**Status:** Approved. Ready to merge."
```

```bash
cd ..
```

##### Sub-state: Needs Stakeholder Input

Check if this is an interactive session (user is present) or a Ralph
session (autonomous).

**If interactive (user present):**

Delegate to the `stakeholder-facilitator` sub-agent:
- "Issue #[NUMBER] needs stakeholder input."
- "PR #[PR_NUMBER] on branch [branch-name]."
- "Read the review comments and facilitate resolution with the user."

The facilitator handles the full cycle: reads comments, walks user through
findings, edits docs, pushes, updates issue.

**If autonomous (Ralph session):**

Do NOT attempt to facilitate without the user. Instead:
- Report: "Issue #[NUMBER] needs stakeholder input. Ralph will stop."
- Ensure the `needs-stakeholder-input` label is present
- Update `[DOCS_REPO]/STATUS.md`:
  ```bash
  cd [DOCS_REPO]
  git add STATUS.md
  git commit -m "status: review waiting for stakeholder input — #[NUMBER]"
  git push origin main
  cd ..
  ```
- Stop gracefully

##### Sub-state: Approved

Verify CI before merging:

```bash
cd [DOCS_REPO]
gh pr checks [PR_NUMBER] --repo [owner/docs-repo] --required --fail
```

If CI fails, do NOT merge. Route back to the review team to fix. Only
proceed with merge when CI is green:

```bash
gh pr merge [PR_NUMBER] --squash --delete-branch
gh issue edit [NUMBER] --remove-label "pipeline:review" --add-label "pipeline:decompose"
gh issue comment [NUMBER] --body "PRDs approved and merged. Issue advanced to pipeline:decompose.

**Status:** approved, PR merged, advanced to decompose"
```

Update STATUS.md (direct to main):
- Move the review issue row from Active Work/In Flight to Recently Completed
- Update Phase in Project Overview to "Decompose"

```bash
git checkout main && git pull origin main
# Edit STATUS.md sections
git add STATUS.md
git commit -m "status: PRDs approved, advancing to decompose — #[NUMBER]"
git push origin main
cd ..
```

---

#### Stage: `pipeline:decompose`

Read the latest issue comment to determine the decompose sub-state.
The decompose phase uses a PR review cycle — PM and architect review
the roadmap PR with actual PR comments (same mechanism as the review phase):

| What you see | Sub-state | Next action |
|-------------|-----------|-------------|
| No `**Status:**` comment from agents | **Needs decomposition** | Dispatch coordinator (full cycle) |
| `**Status:** decomposition proposed, PR ready for review` | **PR under review** | Dispatch PM + architect to review the PR |
| `**Status:** PR reviewed, N concerns addressed — re-review requested` | **PR under review** | Dispatch PM + architect to re-review |
| `**Status:** PR reviewed, approved` | **Approved** | Check CI, merge PR, create epic issues |
| `**Status:** escalated to stakeholder` | **Needs stakeholder** | If interactive: engage user. If Ralph: stop |
| `**Status:** stakeholder input provided` | **Needs revision** | Dispatch coordinator to revise |
| `needs-stakeholder-input` label present | **Waiting for user** | Stop (Ralph) or engage user (interactive) |

##### Sub-state: Needs Decomposition

Dispatch the `project-coordinator` as the primary agent:

- "Issue #[NUMBER] is at pipeline:decompose."
- "Read all approved PRDs in docs/prd/ and discovery docs in docs/discovery/."
- "Delegate product analysis to the product-manager (groupings, foundational
  product epics) and technical analysis to the architect (foundational
  design epics, infrastructure, dependencies) — in parallel where possible."
- "Produce the roadmap from their inputs (process artifact — you own this
  document but do not write technical or product analysis yourself)."
- "Create a branch and PR (NOT draft), then manage the PR review cycle
  with PM and architect. Route revision concerns to the owning sub-agent."
- "Use the roadmap template at docs/planning/templates/roadmap-template.md."

The coordinator handles the full decompose cycle internally: delegating
analysis to PM and architect, producing the roadmap from their outputs,
creating the PR, dispatching PM and architect for PR review, routing
concerns to the owning sub-agent, and re-requesting review (up to 3
cycles before escalating).

##### Sub-state: Approved (PR reviewed, approved)

Both PM and architect have approved the roadmap PR. Verify CI before merging:

```bash
cd [DOCS_REPO]
gh pr checks [PR_NUMBER] --repo [owner/docs-repo] --required --fail
```

If CI fails, do NOT merge. Route back to the coordinator to fix. Only
proceed with merge when CI is green:

```bash
gh pr merge [PR_NUMBER] --squash --delete-branch
```

Create epic issues for each epic in the roadmap. For each epic:

```bash
gh issue create \
  --title "EPIC: [Epic Title]" \
  --label "type:epic,pipeline:design,initiative:[tag]" \
  --body "[structured body from roadmap — overview, source PRDs, scope, acceptance criteria, dependencies]"
```

Close the decompose issue:

```bash
gh issue edit [NUMBER] \
  --remove-label "pipeline:decompose" \
  --add-label "pipeline:done"
gh issue comment [NUMBER] --body "## Decomposition Complete

Created [N] epic issues at pipeline:design.
Roadmap merged: docs/planning/roadmap.md

**Status:** decomposition complete, [N] epics created"
gh issue close [NUMBER]
```

Update STATUS.md (direct to main):
- Move decompose issue to Recently Completed
- Add each epic issue to Active Work / In Flight:
  ```
  | #[N] | EPIC: [title] | design | [level] | Ready |
  ```
- Update Phase in Project Overview to "Design"

```bash
git checkout main && git pull origin main
git add STATUS.md
git commit -m "status: decomposition complete — [N] epics created from #[NUMBER]"
git push origin main
cd ..
```

##### Sub-state: Needs Stakeholder Input

Same pattern as the review phase:

**If interactive:** engage the user directly. Read the escalation summary
from the issue comments, discuss the unresolved concerns, and once the
user provides direction, update the issue comment and remove the
`needs-stakeholder-input` label. Then dispatch the coordinator to revise.

**If autonomous (Ralph):** stop gracefully. Ensure the label is present,
update STATUS.md, report.

##### Sub-state: Needs Revision

The coordinator needs to address PR review feedback.
Re-dispatch the coordinator:

- "Issue #[NUMBER] needs revision based on PR review feedback."
- "Read the PR comments from PM and architect."
- "Route each concern to the owning sub-agent (product concerns to PM,
  technical concerns to architect) for revised content."
- "Update the roadmap on the PR branch and re-request review."

---

#### Stage: `pipeline:design`

Read the latest issue comment to determine the design sub-state.
The design phase uses a PR review cycle — the design team reviews
the design PR with PR comments (same mechanism as review and decompose):

| What you see | Sub-state | Next action |
|-------------|-----------|-------------|
| No `**Status:**` comment from agents | **Needs design** | Dispatch coordinator (full design cycle) |
| `**Status:** spike needed: [unknowns]` | **Spike needed** | Coordinator runs time-boxed spike |
| `**Status:** design proposed, PR ready for review` | **PR under review** | Review team reviews the PR |
| `**Status:** PR reviewed, N concerns addressed — re-review requested` | **PR under review** | Review team re-reviews |
| `**Status:** PR reviewed, approved` | **Approved** | Check CI, merge PR, decompose into tasks |
| `**Status:** design complete, N tasks created` | **Tasks created** | Advance epic to implement |
| `**Status:** escalated to stakeholder` | **Needs stakeholder** | If interactive: engage user. If Ralph: stop |
| `**Status:** needs-redecompose: [reason]` | **Needs re-decompose** | Send epic back to `pipeline:decompose` |
| `needs-stakeholder-input` label present | **Waiting for user** | Stop (Ralph) or engage user (interactive) |

##### Sub-state: Needs Design

Dispatch the `project-coordinator` as the primary agent:

- "Issue #[NUMBER] is at pipeline:design."
- "Read the epic, linked PRDs, existing designs, and repos.yaml."
- "Assess scope and complexity. Assemble the design team based on
  repos/stacks involved."
- "If unknowns warrant a spike, run a time-boxed investigation first."
- "Delegate all design production to the architect and specialists —
  you do not write design content yourself."
- "Collate sub-agent outputs into the design document (editor, not
  author), create a branch and design PR (NOT draft), then manage the
  PR review cycle with the design team."
- "Route revision concerns to the sub-agent who owns that content."
- "After approval, decompose into tasks by invoking relevant engineer
  agents for task boundary advice, then assemble and create task issues."
- "Use the design template at docs/planning/templates/design-template.md."

**Epic ordering:** Level 0 (foundational) epics are designed first —
their outputs constrain all subsequent designs. Within a level, follow
the dependency order from the roadmap (`docs/planning/roadmap.md`).

The coordinator handles the full design cycle internally: assessment,
team assembly, delegating design production to sub-agents, collating
outputs, PR creation, review cycle (routing concerns to owning
sub-agents), and task decomposition with engineer input (up to 3
review cycles before escalating).

##### Sub-state: Spike Needed

The coordinator has identified genuine unknowns that need investigation
before committing to a full design. The coordinator delegates the spike
to the architect (and relevant specialists) for a time-boxed
investigation in a throwaway branch.

On completion, the coordinator updates the issue with a comment
including `**Status:** spike completed, findings recorded` and the
epic returns to the Needs Design state with spike findings available.
Re-dispatch the coordinator to continue with the full design.

##### Sub-state: Approved (PR reviewed, approved)

All reviewers have approved the design PR. Verify CI before merging:

```bash
cd [DOCS_REPO]
gh pr checks [PR_NUMBER] --repo [owner/docs-repo] --required --fail
```

If CI fails, do NOT merge. Route back to the coordinator to fix. Only
proceed with merge when CI is green:

```bash
gh pr merge [PR_NUMBER] --squash --delete-branch
```

**Repo provisioning gate:** Before creating task issues, the coordinator
must verify that all component repos referenced in the design exist:

```bash
gh repo view [owner/repo] --json name --jq .name
```

If a repo does not exist, the coordinator must either provision it
(using the `/repo-provision` skill) or raise a blocker issue. Do not
create task issues targeting a repo that does not exist.

The coordinator creates task issues in the appropriate component repos
(from `repos.yaml`) at `pipeline:implement`. Each task references the
design doc and the epic, with scope, acceptance criteria, and quality
gates inherited from the design.

After tasks are created, the coordinator updates the epic issue:

```bash
gh issue comment [NUMBER] --body "## Design Complete

Design PR merged. Tasks created:
- [repo]#[N1]: [title]
- [repo]#[N2]: [title]

**Status:** design complete, [N] tasks created"
```

When "tasks created" is detected, advance the epic. The epic issue
stays open as a tracking umbrella — individual task issues drive
implementation.

Update STATUS.md (direct to main):
- Move epic design row to Recently Completed
- Update the epic's Active Work row stage to "implement"
- Update Phase in Project Overview to "Implement" if all epics are
  past design
- Add a Watch Item if design outputs affect other in-flight work

##### Sub-state: Needs Stakeholder Input

Same pattern as the review and decompose phases:

**If interactive:** engage the user directly. Read the escalation summary
from the issue comments, discuss the unresolved design concerns, and once
the user provides direction, update the issue comment and remove the
`needs-stakeholder-input` label. Then dispatch the coordinator to revise.

**If autonomous (Ralph):** stop gracefully. Ensure the label is present,
update STATUS.md, report.

##### Sub-state: Needs Re-Decompose

The design has revealed the epic's scope is fundamentally wrong.
Send the epic back to `pipeline:decompose`:

```bash
cd [DOCS_REPO]
gh issue edit [NUMBER] --remove-label "pipeline:design" --add-label "pipeline:decompose"
gh issue comment [NUMBER] --body "Sent back to decompose: [reason from coordinator comment]

**Status:** needs-redecompose: [reason]"
cd ..
```

The roadmap will need updating and re-review. This is a safety valve,
not a common path.

---

#### Stage: Unsubmitted PRDs (Discovery → Review bridge)

This stage is detected in Orient (step 4) when there are no open pipeline
issues but PRD files exist in `docs/prd/` (excluding `templates/`). This
bridges the gap between manual Discovery and the automated pipeline —
the orchestrator handles submission automatically so neither the user
nor Ralph needs to run `/submit-prds` separately.

**Step 1: Verify PRDs are ready**

```bash
cd [DOCS_REPO]
git checkout main && git pull origin main
```

Check that PRD files exist and are committed (or at least present):
```bash
ls docs/prd/*.md 2>/dev/null | grep -v templates/
```

If there are uncommitted PRD files, stage and commit them first:
```bash
git add docs/prd/ docs/discovery/
git status --porcelain docs/prd/ docs/discovery/
```

If nothing to commit and nothing already committed in `docs/prd/`
(excluding templates), stop — there's genuinely nothing to submit.

**Step 2: Determine submission number**

```bash
git branch -a | grep "prd-submission" || echo "No prior submissions"
gh issue list --label "type:prd-review" --json number,title --state all
```

Use the next sequential number (e.g., `001`, `002`, etc.).

**Step 3: Create branch, commit, push, PR, and issue**

Follow the same mechanics as the `/submit-prds` skill:

```bash
git checkout -b docs/prd-submission-[NNN]
git add docs/prd/ docs/discovery/
git commit -m "docs: submit PRDs for review

Submits the following PRDs for pipeline review:
$(ls docs/prd/*.md 2>/dev/null | grep -v templates/ | sed 's/docs\/prd\//- /')"
git push origin docs/prd-submission-[NNN]
```

Create the PR:
```bash
gh pr create \
  --title "docs: PRD submission [NNN] for review" \
  --body "## PRD Submission

### PRDs submitted
$(ls docs/prd/*.md 2>/dev/null | grep -v templates/ | sed 's/^/- /')

### Discovery docs
$(ls docs/discovery/*.md 2>/dev/null | grep -v templates | sed 's/^/- /' || echo '- (none)')

### Process
This PR will be reviewed by the review team (product-manager + architect).
Review findings will appear as PR comments.
The stakeholder facilitator will walk through any items needing input.

Closes #[ISSUE_NUMBER]"
```

Create the issue:
```bash
gh issue create \
  --title "PRD Review: submission [NNN]" \
  --label "type:prd-review,pipeline:review" \
  --body "## PRD Review Cycle

**Submission:** [NNN]
**PR:** #[PR_NUMBER]
**PRDs:**
$(ls docs/prd/*.md 2>/dev/null | grep -v templates/ | sed 's/^/- /')

### Review State
Awaiting first review by review team.

### Process
1. Review team analyses PRDs (autonomous)
2. Stakeholder facilitator walks through findings (interactive)
3. Review team re-reviews until clean
4. Merge PR, advance to pipeline:decompose"
```

Link the PR to the issue (update PR body with actual issue number).

**Step 4: Update STATUS.md and return to main**

```bash
git checkout main
```

Update `[DOCS_REPO]/STATUS.md`:
- Set phase to "Review"
- Add the issue to the Active Work table
- Note the PR number

```bash
git add STATUS.md
git commit -m "status: PRDs submitted for review — issue #[NUMBER]"
git push origin main
cd ..
```

**Step 5: Continue orchestration**

The `pipeline:review` issue now exists. Continue to Phase 2 (Decide)
and handle it as a normal review — do NOT stop and require another
orchestrate cycle.

---

#### Stage: `pipeline:implement`

Implementation tasks live in **component repos** (not the docs repo).
The orchestrator reads task issues across all component repos listed in
`repos.yaml`. Each task follows the same sub-state machine as other
phases — production step (engineer codes) + review cycle (specialist
team reviews PR).

**Discovering tasks:** During Orient, read task issues across component
repos:

```bash
cd [DOCS_REPO]
```

Read `repos.yaml` to get the list of component repos. For each component
repo:

```bash
gh issue list --repo [owner/repo] --label "pipeline:implement" \
  --state open --json number,title,labels,body
```

```bash
cd ..
```

Read the latest comment on each task issue to determine sub-state.

| What you see | Sub-state | Next action |
|-------------|-----------|-------------|
| No `**Status:**` comment from agents, no `claimed:*` label | **Ready** | Dispatch coordinator for this task |
| `**Status:** claimed by [session]` or `claimed:*` label | **In progress** | Skip — engineer is working |
| `**Status:** implementation complete, PR #NNN ready for review` | **PR ready** | Same coordinator invocation manages the review cycle |
| `**Status:** PR under review` | **Under review** | Skip — reviewers working |
| `**Status:** PR reviewed, N concerns raised` | **Needs changes** | Dispatch coordinator to route concerns to engineer |
| `**Status:** PR reviewed, N concerns addressed — re-review requested` | **Re-review needed** | Dispatch coordinator to re-dispatch review team |
| `**Status:** PR reviewed, approved` | **Approved** | Check CI, merge PR, advance task to `pipeline:done` |
| `**Status:** escalated to stakeholder` | **Needs stakeholder** | If interactive: engage user. If Ralph: stop |
| `**Status:** blocked: amendment #NNN` | **Blocked** | Check if amendment resolved; if so, unblock and treat as ready |
| `needs-stakeholder-input` label | **Waiting for user** | Stop (Ralph) or engage user (interactive) |

##### Sub-state: Ready (task unclaimed, no `**Status:**` comments)

Check the task's dependencies (listed in the task issue body). If
dependencies are not met (referenced tasks not at `pipeline:done`),
skip this task.

If dependencies are met, **claim the task atomically before dispatching
the coordinator.** This prevents concurrent sessions from picking up
the same task.

**Claiming protocol (orchestrator does this, not coordinator):**

```bash
# 1. Apply claimed label FIRST — this is the atomic lock
gh issue edit [TASK_NUMBER] --repo [owner/repo] \
  --add-label "claimed:[SESSION_ID]"

# 2. Post claim comment on the issue
gh issue comment [TASK_NUMBER] --repo [owner/repo] \
  --body "Claimed by session [SESSION_ID].

**Status:** claimed by [SESSION_ID]"
```

```bash
# 3. Update STATUS.md — Active Sessions + In Flight
cd [DOCS_REPO]
git checkout main && git pull origin main
```

Add to Active Sessions:
```
| [SESSION_ID] | #[NUMBER] [short-title] | [timestamp UTC] | Implementing |
```

Add to In Flight:
```
| #[NUMBER] | [repo] | [title] | In progress | [SESSION_ID] |
```

```bash
git add STATUS.md
git commit -m "status: claimed #[NUMBER] for implementation"
git push origin main
cd ..
```

**Only after claiming succeeds**, dispatch the `project-coordinator`
**using worktree isolation** to prevent filesystem collisions with other
sessions working on the same repo:

```
Agent(
  prompt: [coordinator brief below],
  subagent_type: "project-coordinator",
  isolation: "worktree"
)
```

The worktree is created from the component repo's current `main`. The
coordinator and all its sub-agents (engineer, reviewers) operate in the
isolated worktree directory. This ensures each session has its own
working directory, index, and HEAD — no interference with concurrent
sessions on the same repo.

Coordinator brief:

- "Task #[NUMBER] in [repo-name] is at pipeline:implement and ready."
- "You are operating in a git worktree — an isolated copy of the repo.
  Git commands work normally. Use `--repo [owner/repo]` for all `gh`
  commands. Read docs repo content via absolute path: `[DOCS_REPO]/`."
- "Read the task issue for scope, acceptance criteria, and quality gates."
- "Read the design doc at `[DOCS_REPO]/docs/architecture/[epic-name]/`."
- "Read the component repo's manifest files (package.json, *.csproj,
  pyproject.toml, etc.) and agent descriptions to select the appropriate
  engineer for this repo's stack. Do not use a rigid lookup table —
  read the repo context and match to agent capabilities."
- "Dispatch the selected engineer sub-agent."
- "The engineer should: read the codebase, create a feature branch,
  implement, write tests, ensure CI passes (build + test + lint),
  create a PR (NOT draft), and update the task issue with:
  '**Status:** implementation complete, PR #NNN ready for review'."
- "After the engineer reports back, verify CI is green on the PR:
  `gh pr checks [PR_NUMBER] --repo [owner/repo] --required --fail`"
- "Then assemble the review team dynamically: read the PR diff, the
  repo manifest files, and agent descriptions to select reviewers.
  Principles: peer engineer (always), architect (if APIs/integration),
  specialist reviewers (based on what the PR touches),
  spec-compliance as final gate (if PRD-linked). Not every task needs
  every reviewer — assemble the minimum viable review team."
- "Manage the full review cycle: route concerns to engineer, verify
  CI after each revision, re-dispatch reviewers, until all approve
  or circuit breaker triggers."

##### Sub-state: PR Ready (implementation complete)

This sub-state is handled by the same coordinator invocation that
started the task. If the orchestrator encounters a task at this
sub-state without an active coordinator (e.g., session interrupted),
re-dispatch the `project-coordinator` **with worktree isolation**
to pick up from the review cycle:

- "Task #[NUMBER] in [repo-name] has a PR ready for review."
- "You are operating in a git worktree. Use `--repo [owner/repo]` for
  all `gh` commands. Read docs repo content via absolute path."
- "Verify CI is green: `gh pr checks [PR_NUMBER] --repo [owner/repo] --required --fail`"
- "If CI fails, route back to the engineer to fix."
- "Read the PR diff, repo manifest files, and agent descriptions to
  assemble the review team dynamically. Do not use a rigid lookup
  table — match reviewers to what the PR touches."
- "Manage the review cycle through to completion."

##### Sub-state: Needs Changes (concerns raised)

Re-dispatch the coordinator **with worktree isolation** to route review
concerns to the implementation engineer:

- "PR #[NUMBER] in [repo-name] has reviewer concerns."
- "You are operating in a git worktree. Use `--repo [owner/repo]` for
  all `gh` commands. Read docs repo content via absolute path."
- "Route the concerns to the implementation engineer."
- "The engineer addresses concerns, ensures CI passes, pushes to the
  PR branch, and updates the task issue with:
  '**Status:** PR reviewed, N concerns addressed — re-review requested'."

##### Sub-state: Re-review Needed

Re-dispatch the coordinator **with worktree isolation** to re-dispatch
the review team (or the subset whose concerns were addressed).

##### Sub-state: Approved (all reviewers approve)

Verify CI before merging:

```bash
cd [component-repo]
gh pr checks [PR_NUMBER] --repo [owner/repo] --required --fail
```

If CI fails, do NOT merge. Route back to the engineer to fix. Only
proceed with merge when CI is green:

```bash
gh pr merge [PR_NUMBER] --squash --delete-branch
gh issue edit [TASK_NUMBER] \
  --remove-label "pipeline:implement" \
  --add-label "pipeline:done"
gh issue comment [TASK_NUMBER] --body "PR reviewed, approved. PR merged.

**Status:** PR reviewed, approved. PR merged, task complete."
gh issue close [TASK_NUMBER]
cd ..
```

Remove any `claimed:*` label.

Update STATUS.md (direct to main):

```bash
cd [DOCS_REPO]
git checkout main && git pull origin main
```

- Remove the task row from In Flight
- Add to Recently Completed:
  ```
  | #[NUMBER] | [title] | [date] | [repo]#[PR_NUMBER] |
  ```
- Remove the session row from Active Sessions
- Update any Watch Items if this task affects downstream work

```bash
git add STATUS.md
git commit -m "status: task #[NUMBER] complete — PR merged"
git push origin main
cd ..
```

After merging, check if all tasks for the parent epic are now done:

```bash
cd [DOCS_REPO]
```

Read the epic issue — check all linked task issues across component repos.
If all tasks are at `pipeline:done`:

- Run a final integration check (build + test in all affected repos)
- Update the epic issue: "All tasks complete. Implementation done."
- Advance the epic: remove `pipeline:implement`, add `pipeline:deliver`

```bash
cd ..
```

If not all tasks are done, just update STATUS.md with progress.

##### Sub-state: Needs Stakeholder Input

Same pattern as all other phases:

**If interactive:** engage the user directly. Read the escalation summary
from the task issue comments, discuss the unresolved concerns, and once
the user provides direction, update the issue comment and remove the
`needs-stakeholder-input` label. Then dispatch the coordinator to route
direction to the engineer.

**If autonomous (Ralph):** stop gracefully. Ensure the label is present,
update STATUS.md, report.

##### Sub-state: Blocked

The task is blocked by an amendment issue in the docs repo. When a
blocked task is encountered, check whether the blocking amendment has
been resolved:

```bash
gh issue view [AMENDMENT_NUMBER] --repo [owner/docs-repo] --json state --jq .state
```

If the amendment state is `"CLOSED"`, the blocker is resolved. Remove
the `blocked` label from the task and treat it as ready:

```bash
gh issue edit [TASK_NUMBER] --repo [owner/repo] --remove-label "blocked"
gh issue comment [TASK_NUMBER] --repo [owner/repo] --body "Amendment #[AMENDMENT_NUMBER] resolved. Task unblocked.

**Status:** unblocked, ready for implementation"
```

Update STATUS.md: move the task row from Blocked back to In Flight
(status: `In progress`).

Then dispatch the coordinator for this task as per the Ready sub-state
(claiming protocol applies — the task needs to be re-claimed).

If the amendment is still `"OPEN"`, skip this task until the next
orchestration cycle.

##### Task Selection

When multiple tasks are actionable, the orchestrator picks **one task
per cycle** based on priority:

1. Tasks with approved PRs needing merge (quick wins, unblock dependents)
2. Tasks whose blockers just resolved (newly unblocked work)
3. Tasks with review concerns needing routing (keep PRs moving)
4. New tasks ready for implementation (dependencies met, unclaimed)

The orchestrator dispatches **one coordinator per task**. Each
coordinator invocation drives its task through the full implementation
and review cycle. Do not batch multiple tasks into a single coordinator
dispatch.

**Concurrency safety:** In concurrent mode (multiple terminals), each
session claims one task at a time via the claiming protocol above
(`claimed:[SESSION_ID]` label + STATUS.md Active Sessions). During
Orient, if a task has a `claimed:*` label, skip it — another session
owns it. If a task has a `claimed:*` label but no matching Active
Sessions row and the label is >4 hours old, treat as stale: remove
the label and the row, then claim normally.

In sequential mode (single Ralph), handle the highest-priority task
per cycle.

---

#### Stage: Not Yet Implemented

For any other `pipeline:*` stage:

- Report: "Issue #[NUMBER] is at [stage], which is not yet implemented."
- Update STATUS.md with the current state
- Stop

---

### Phase 4: Update State

After execution:

1. Update STATUS.md sections as appropriate for the action taken (see STATUS.md Section Format below)
2. Ensure all commits are pushed

---

### STATUS.md Section Format

STATUS.md contains these operational sections. Agents update the
**specific section** for the event — not the whole file. All STATUS.md
updates go direct to main:

```bash
cd [DOCS_REPO]
git checkout main && git pull origin main
# Update specific STATUS.md sections
git add STATUS.md
git commit -m "status: [action summary]"
git push origin main
cd ..
```

#### Active Sessions

Tracks which sessions are currently working. Used to detect stale
claims and prevent concurrent work collisions.

```markdown
## Active Sessions

| Session | Task | Started | Notes |
|---------|------|---------|-------|
| ralph-001 | #95 observability | 2026-03-14 21:00 UTC | Implementing |
```

- Add row when session starts working on a task
- Remove row when session completes or exits
- If a row is older than 4 hours with no matching `claimed:*` label
  on the issue, treat it as stale — remove the row and unclaim the task

#### In Flight

Tracks tasks currently being worked on and their progress.

```markdown
## In Flight

| Issue | Repo | Title | Status | Owner |
|-------|------|-------|--------|-------|
| #95 | api | Observability | In progress | ralph-001 |
| #91 | api | Schema migration | PR created (#3) | ralph-002 |
```

Status values: `In progress`, `PR created (#N)`, `Under review`,
`Addressing N concerns`, `Re-review requested`

- Add row when task is claimed
- Update status as task progresses through sub-states
- Move to Recently Completed when PR is merged
- Move to Blocked if amendment issue created

#### Blocked

```markdown
## Blocked

| Issue | Repo | Title | Blocked By | Notes |
|-------|------|-------|------------|-------|
| #92 | api | ORM models | docs#102 (amendment) | Design gap in schema |
```

- Move here from In Flight when blocked
- Move back to In Flight when blocker resolves

### Session Identity and Mode Detection

Every Claude instance has a unique session ID, established at startup.

**Finding your session ID:**
- **Interactive sessions:** The `on-session-start.sh` hook outputs
  `Session ID: interactive-YYYYMMDDTHHMMSS-PID` at startup. This is
  your session ID for the duration of this Claude instance.
- **Ralph sessions:** The prompt includes
  `Session ID: ralph-YYYYMMDDTHHMMSS-PID`.

**Use your session ID for all claiming operations** — add
`claimed:[your-session-id]` labels to issues you work on, and skip
issues with a `claimed:` label from a different session ID.

**Mode detection is simple:**
- If your session ID starts with `ralph-` → autonomous mode (user NOT
  present). Stop when stakeholder input is needed.
- If your session ID starts with `interactive-` → interactive mode
  (user IS present). Can engage the user directly.

If you cannot find a session ID in your startup output or prompt,
generate one: `interactive-[current-timestamp]-unknown`. Default to
interactive if the user invoked you directly.
