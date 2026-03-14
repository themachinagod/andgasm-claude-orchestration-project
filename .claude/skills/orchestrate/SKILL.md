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

1. Read `[DOCS_REPO]/STATUS.md` — project-level source of truth
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
   - If PRD files exist (outside `templates/`): this is the Discovery → Review
     transition. Run the submit-prds logic (see **Stage: Unsubmitted PRDs** below)
     to create the branch, PR, and `pipeline:review` issue, then continue
     orchestration with the newly created issue.
   - If no PRD files exist either:
     - Report: "No open pipeline issues and no PRDs to submit. Nothing to orchestrate."
     - Update STATUS.md if needed
     - `cd ..` and stop
5. For each pipeline issue, read the comments to determine sub-state:
   ```bash
   gh issue view [NUMBER] --json comments --jq '.comments[-1].body'
   ```
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
4. Any other `pipeline:*` — report "not yet implemented" and stop

If multiple issues exist, handle the highest-priority one. Priority
follows the orchestration priority in `.claude/rules/pipeline.md`.

Skip rules:
- `blocked` label → skip until blocker resolved
- `needs-stakeholder-input` → if interactive: can handle. If Ralph: stop.

### Phase 3: Execute

Based on the pipeline stage, dispatch the appropriate logic:

---

#### Stage: `pipeline:review`

Read the latest issue comment to determine the review sub-state:

| What you see | Sub-state | Next action |
|-------------|-----------|-------------|
| No comments from agents (just the original body) | **Needs first review** | Invoke Review Team |
| Latest comment contains "items need stakeholder input" | **Needs stakeholder input** | Check if interactive, invoke Facilitator or stop |
| Latest comment contains "input provided, ready for re-review" | **Needs re-review** | Invoke Review Team |
| Latest comment contains "approved" or "all clean" | **Approved** | Merge PR, advance label |
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

Merge the PR and advance the issue:

```bash
cd [DOCS_REPO]
gh pr merge [PR_NUMBER] --squash --delete-branch
gh issue edit [NUMBER] --remove-label "pipeline:review" --add-label "pipeline:decompose"
gh issue comment [NUMBER] --body "PRDs approved and merged. Issue advanced to pipeline:decompose."
```

Update STATUS.md:
```bash
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
| No agent comments (just the original body) | **Needs decomposition** | Dispatch coordinator (full cycle) |
| "decomposition proposed, PR ready for review" | **PR under review** | Dispatch PM + architect to review the PR |
| "PR reviewed, N concerns addressed — re-review requested" | **PR under review** | Dispatch PM + architect to re-review |
| "PR reviewed, approved" | **Approved** | Merge PR, create epic issues |
| "escalated to stakeholder" | **Needs stakeholder** | If interactive: engage user. If Ralph: stop |
| "stakeholder input provided" | **Needs revision** | Dispatch coordinator to revise |
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

Both PM and architect have approved the roadmap PR. Merge and create
epic issues:

```bash
cd [DOCS_REPO]
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
Roadmap merged: docs/planning/roadmap.md"
gh issue close [NUMBER]
```

Update STATUS.md:

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
| No agent comments (just the original body) | **Needs design** | Dispatch coordinator (full design cycle) |
| "spike needed: [unknowns]" | **Spike needed** | Coordinator runs time-boxed spike |
| "design proposed, PR ready for review" | **PR under review** | Review team reviews the PR |
| "PR reviewed, N concerns addressed — re-review requested" | **PR under review** | Review team re-reviews |
| "PR reviewed, approved" | **Approved** | Merge PR, decompose into tasks |
| "design complete, N tasks created" | **Tasks created** | Advance epic to implement |
| "escalated to stakeholder" | **Needs stakeholder** | If interactive: engage user. If Ralph: stop |
| "needs-redecompose: [reason]" | **Needs re-decompose** | Send epic back to `pipeline:decompose` |
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

On completion, the coordinator updates the issue comment to
"spike completed, findings recorded" and the epic returns to the
Needs Design state with spike findings available. Re-dispatch the
coordinator to continue with the full design.

##### Sub-state: Approved (PR reviewed, approved)

All reviewers have approved the design PR. The coordinator merges the
PR and decomposes into tasks (invoking relevant engineer agents for
task boundary advice, then assembling and creating task issues):

```bash
cd [DOCS_REPO]
gh pr merge [PR_NUMBER] --squash --delete-branch
```

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
gh issue comment [NUMBER] --body "Sent back to decompose: [reason from coordinator comment]"
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

#### Stage: Not Yet Implemented

For any other `pipeline:*` stage:

- Report: "Issue #[NUMBER] is at [stage], which is not yet implemented."
- Update STATUS.md with the current state
- Stop

---

### Phase 4: Update State

After execution:

1. Update `[DOCS_REPO]/STATUS.md` with what was done (if not already done above)
2. Ensure all commits are pushed

### Detecting Interactive vs. Autonomous

When invoked by ralph.sh, the session is non-interactive — the user is NOT
present. Ralph passes a prompt that includes "autonomous session" or similar.

When invoked directly by the user (e.g., they type `/orchestrate` in Claude),
the session IS interactive.

The key difference: in an interactive session, you CAN engage the user
directly (invoke facilitator, discuss decomposition concerns). In an
autonomous session, you MUST stop when stakeholder input is needed.

If unsure whether the session is interactive, check: was the prompt
structured as a ralph.sh prompt (contains "autonomous" or structured
orchestration instructions) or was it a direct user request? Default to
autonomous (safer — don't try to engage without a user).
