---
name: orchestrate
description: >
  Pipeline orchestrator. Reads project state, determines the pipeline stage
  and sub-state for open issues, and dispatches the appropriate agent team.
  Handles review and decompose stages. Designed to be called by ralph.sh
  for autonomous operation or interactively by the user.
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
4. If no pipeline issues exist:
   - Report: "No open pipeline issues. Nothing to orchestrate."
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

1. `pipeline:review` — review and facilitation cycle
2. `pipeline:decompose` — PRDs → epics + roadmap
3. Any other `pipeline:*` — report "not yet implemented" and stop

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

Read the latest issue comment to determine the decompose sub-state:

| What you see | Sub-state | Next action |
|-------------|-----------|-------------|
| No agent comments (just the original body) | **Needs decomposition** | Dispatch coordinator |
| "decomposition proposed, awaiting sign-off" | **Awaiting PM sign-off** | Coordinator handles internally |
| "sign-off: approved" | **Approved** | Merge PR, create epic issues |
| "sign-off: concerns" | **Needs revision** | Dispatch coordinator to revise |
| "revision N" | **Revised, awaiting sign-off** | Coordinator handles internally |
| "escalated to stakeholder" | **Needs stakeholder** | If interactive: engage user. If Ralph: stop |
| "stakeholder input provided" | **Needs revision** | Dispatch coordinator to revise |
| `needs-stakeholder-input` label present | **Waiting for user** | Stop (Ralph) or engage user (interactive) |

##### Sub-state: Needs Decomposition

Dispatch the `project-coordinator` as the primary agent:

- "Issue #[NUMBER] is at pipeline:decompose."
- "Read all approved PRDs in docs/prd/ and discovery docs in docs/discovery/."
- "Invoke the product-manager for product groupings and the architect for
  technical analysis."
- "Synthesize into a roadmap document, create a branch and PR, then get
  PM sign-off."
- "Use the roadmap template at docs/planning/templates/roadmap-template.md."

The coordinator handles the full decompose cycle internally: gathering
input from PM and architect, producing the roadmap, managing the sign-off
loop (up to 3 revisions), and escalating if needed.

##### Sub-state: Approved (sign-off: approved)

The PM has approved the roadmap. Merge and create epic issues:

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

##### Sub-state: Needs Revision / Revised

The coordinator is still working through the sign-off cycle. Re-dispatch
the coordinator to continue:

- "Issue #[NUMBER] needs revision based on PM feedback."
- "Read the latest PM concerns from the issue comments."
- "Revise the roadmap on the PR branch and re-request sign-off."

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
