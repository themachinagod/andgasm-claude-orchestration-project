---
name: orchestrate-review
description: >
  Focused review-phase orchestrator. Reads project state, determines the
  review sub-state for pipeline:review issues, and dispatches the appropriate
  agent (review team or stakeholder facilitator). Designed to be called by
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
3. Check for `pipeline:review` issues:
   ```bash
   cd [DOCS_REPO]
   gh issue list --state open --label "pipeline:review" \
     --json number,title,labels,body
   ```
4. If no `pipeline:review` issues exist:
   - Report: "No issues at pipeline:review. Nothing to orchestrate."
   - Update STATUS.md if needed
   - `cd ..` and stop
5. For each review issue, read the comments to determine sub-state:
   ```bash
   gh issue view [NUMBER] --json comments --jq '.comments[-1].body'
   ```
6. Check for associated PR:
   ```bash
   gh pr list --json number,title,headRefName,body \
     | jq '.[] | select(.body | contains("#[ISSUE_NUMBER]"))'
   ```
7. `cd ..` to return to workspace root

### Phase 2: Determine Sub-State

Read the latest issue comment to determine where we are in the review cycle:

| What you see | Sub-state | Next action |
|-------------|-----------|-------------|
| No comments from agents (just the original body) | **Needs first review** | Invoke Review Team |
| Latest comment contains "items need stakeholder input" | **Needs stakeholder input** | Check if interactive, invoke Facilitator or stop |
| Latest comment contains "input provided, ready for re-review" | **Needs re-review** | Invoke Review Team |
| Latest comment contains "approved" or "all clean" | **Approved** | Merge PR, advance label |
| `needs-stakeholder-input` label present | **Waiting for user** | Stop (Ralph) or invoke Facilitator (interactive) |

### Phase 3: Execute

Based on the sub-state, take the appropriate action:

#### Sub-state: Needs First Review / Needs Re-Review

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

#### Sub-state: Needs Stakeholder Input

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
  # Update STATUS.md to note review is waiting for stakeholder
  git add STATUS.md
  git commit -m "status: review waiting for stakeholder input — #[NUMBER]"
  git push origin main
  cd ..
  ```
- Stop gracefully

#### Sub-state: Approved

Merge the PR and advance the issue:

```bash
cd [DOCS_REPO]
gh pr merge [PR_NUMBER] --squash --delete-branch
gh issue edit [NUMBER] --remove-label "pipeline:review" --add-label "pipeline:decompose"
gh issue comment [NUMBER] --body "PRDs approved and merged. Issue advanced to pipeline:decompose."
```

Update STATUS.md:
```bash
# Update STATUS.md to reflect PRDs approved
git add STATUS.md
git commit -m "status: PRDs approved, advancing to decompose — #[NUMBER]"
git push origin main
cd ..
```

### Phase 4: Update State

After execution:

1. Update `[DOCS_REPO]/STATUS.md` with what was done (if not already done above)
2. Ensure all commits are pushed

### Detecting Interactive vs. Autonomous

When invoked by ralph.sh, the session is non-interactive — the user is NOT
present. Ralph passes a prompt that includes "autonomous session" or similar.

When invoked directly by the user (e.g., they type `/orchestrate-review`
in Claude), the session IS interactive.

The key difference: in an interactive session, you CAN invoke the
stakeholder-facilitator. In an autonomous session, you MUST stop and let
the user start an interactive session.

If unsure whether the session is interactive, check: was the prompt
structured as a ralph.sh prompt (contains "run /orchestrate-review" or
"autonomous") or was it a direct user request? Default to autonomous
(safer — don't try to facilitate without a user).

## Important Notes

- This orchestrator ONLY handles `pipeline:review`. It does not handle
  other pipeline stages. Later phases will extend or replace this with
  a full orchestrator.
- The review team always does a FULL review, not just checking prior
  comments. New issues may emerge from changes made during facilitation.
- The orchestrator is the coordinator — it invokes agents, reads their
  output, synthesizes, and updates state. It does not do the review itself.
- PR comments are the primary mechanism for review feedback. Issue comments
  track the review cycle state.
