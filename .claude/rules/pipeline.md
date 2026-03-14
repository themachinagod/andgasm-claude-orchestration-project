---
description: Pipeline stage definitions, transitions, and orchestration rules
globs: "**/*"
---

# Pipeline Orchestration Rules

## Pipeline Stages

Issues flow through these stages. Never skip stages.

```
Discovery (manual) → Review → Decompose → Design → Implement → Deliver → Done
```

| Stage | Label | What happens |
|-------|-------|-------------|
| Discovery | (none — manual) | User writes PRDs and vision docs in IDE |
| Review | `pipeline:review` | Review team analyses PRDs, stakeholder facilitation cycle |
| Decompose | `pipeline:decompose` | PRDs → epics + roadmap |
| Design | `pipeline:design` | Architecture, UX, task breakdown per epic |
| Implement | `pipeline:implement` | Per-task coding + specialist review in component repos |
| Deliver | `pipeline:deliver` | E2E, docs, release |
| Done | `pipeline:done` | Completed and delivered |

## Review Phase Sub-States

The review phase uses a single `pipeline:review` label throughout. Sub-state
is tracked via issue comments, not additional labels. The only secondary label
is `needs-stakeholder-input` (signals Ralph to stop).

### Sub-State Machine

| Sub-state | Detected by | Next action |
|-----------|------------|-------------|
| Issue just created (no review comments) | No review comment from agents | Review Team analyses PRDs |
| "reviewed, N items need stakeholder input" | Latest agent comment | Stakeholder Facilitator engages user |
| "stakeholder input provided, ready for re-review" | Latest facilitator comment | Review Team re-reviews (full, not just prior) |
| "approved" | Latest agent comment | Merge PR, advance to `pipeline:decompose` |

### Review Team Behavior

The review team (product-manager + architect) analyses ALL PRDs holistically:

1. Read every PRD and discovery doc
2. Product review: completeness, consistency, gaps, scope, success criteria
3. Technical review: feasibility, hidden complexity, NFR realism, risks
4. Fix obvious issues directly (push to PR branch)
5. Leave PR comments for items needing stakeholder decisions
6. Update the issue with a structured comment summarizing findings

### Stakeholder Facilitator Behavior

The facilitator mediates between review findings and the user:

1. Read all open PR review comments and prior cycle context
2. Group and prioritize: conflicts > gaps > suggestions
3. Walk user through each finding conversationally
4. Edit PRD files based on answers, push to PR branch
5. Update issue: "stakeholder input provided, ready for re-review"
6. Remove `needs-stakeholder-input` label

## Decompose Phase Sub-States

The decompose phase uses a single `pipeline:decompose` label throughout.
Sub-state is tracked via issue comments. The `needs-stakeholder-input`
label is only added when the team cannot converge (circuit breaker).

### Decompose Team

| Agent | Role | What they do |
|-------|------|-------------|
| project-coordinator (primary) | Process manager | Delegates analysis to PM and architect, produces roadmap from their inputs (process artifact), manages PR review cycle. Never writes technical or product analysis. |
| product-manager | Product analysis + PR review | Proposes product groupings + foundational product epics, reviews roadmap PR |
| architect | Technical analysis + PR review | Identifies foundational design epics + infrastructure epics, reviews roadmap PR |

### Sub-State Machine

| Sub-state | Detected by | Next action |
|-----------|------------|-------------|
| Issue created (no agent comments) | No decompose comment from agents | Coordinator delegates to PM + architect, produces roadmap |
| "decomposition proposed, PR ready for review" | Coordinator comment | PM + architect review the PR |
| "PR reviewed, N concerns raised" | PM/architect PR comments | Coordinator routes concerns to owning sub-agent |
| "PR reviewed, approved" | PM/architect comment (all concerns resolved) | Merge PR, create epic issues at `pipeline:design` |
| "escalated to stakeholder" | Coordinator comment (3+ review cycles) | If interactive: engage user. If Ralph: stop |
| "stakeholder input provided" | User/facilitator comment | Coordinator revises |

### PR Review Cycle

PM and architect review the roadmap PR with actual PR comments (same
mechanism as the review phase). The coordinator routes each concern to
the sub-agent who owns that content (product concerns to PM, technical
concerns to architect), then updates the branch and requests re-review.
Both PM and architect must approve the PR for it to merge. The
stakeholder is NOT involved unless the circuit breaker triggers.

### Circuit Breaker

If the coordinator and reviewers cycle through 3+ PR review rounds
without converging, the coordinator adds `needs-stakeholder-input` and
writes a summary of what the team cannot resolve. Ralph stops and the
user engages directly.

## Design Phase Sub-States

The design phase uses a single `pipeline:design` label throughout.
Sub-state is tracked via issue comments. The `needs-stakeholder-input`
label is only added when the circuit breaker triggers.

### Design Team (dynamic per epic)

| Agent | When | Role |
|-------|------|------|
| project-coordinator | Always | Process manager: assembles team, delegates all design to sub-agents, collates outputs, manages PR review cycle, task decomposition (with engineer input on boundaries) |
| architect | Always | Primary design producer: system design, cross-epic consistency, ADRs, integration, codebase patterns |
| spec-compliance | If epic has PRD linkage | PRD coverage (vertical) + cross-document consistency (horizontal) |
| frontend-architect | If epic has UI | Component architecture, state management, performance budgets |
| ux-architect | If epic has UX | User flows, interaction design, accessibility |
| engineer-dotnet | If epic touches .NET repos | .NET design + codebase review |
| engineer-python | If epic touches Python repos | Python design + codebase review |
| engineer-angular | If epic touches Angular/TS repos | Angular/TS design + codebase review |
| engineer-typescript | If epic touches Node/TS repos | Node/TS design + codebase review |
| database-engineer | If epic has data concerns | Schema design, query patterns, migrations |
| devops-engineer | If epic has infra concerns | CI/CD, deployment, monitoring |

**Lightweight path:** Not every epic needs the full team. The coordinator
assesses the epic's scope and assembles the minimum viable team. Architect
is always present; spec-compliance is present for any epic with PRD linkage.

### Sub-State Machine

| Sub-state | Detected by | Next action |
|-----------|------------|-------------|
| Needs design (no agent comments) | No design comment from agents | Coordinator assesses + assembles team |
| "spike needed: [unknowns]" | Coordinator comment | Coordinator runs time-boxed spike |
| "design proposed, PR ready for review" | Coordinator comment | Design team reviews the PR |
| "PR reviewed, N concerns" | Reviewer PR comments | Coordinator addresses PR comments |
| "PR reviewed, approved" | All reviewers approve | Merge PR, decompose into tasks |
| "design complete, N tasks created" | Coordinator comment | Advance epic |
| "escalated to stakeholder" | Coordinator comment (3+ cycles) | If interactive: engage user. If Ralph: stop |
| "needs-redecompose: [reason]" | Coordinator comment | Send back to `pipeline:decompose` |

### PR Review Cycle

The coordinator creates the design PR (NOT draft) and requests reviews
from the assembled design team. Reviewers leave PR comments:

- **Architect**: architectural quality, cross-epic integration, pattern consistency
- **Spec-compliance**: PRD coverage, cross-document consistency, terminology
- **Specialists**: stack-specific technical correctness

The coordinator routes each concern to the sub-agent who owns that
content (architecture concerns to architect, stack concerns to the
relevant specialist), takes revised content back, updates the branch,
and re-requests review. Both architect and spec-compliance (when
present) must approve.

### Circuit Breaker

If the coordinator and reviewers cycle through 3+ PR review rounds
without converging, the coordinator adds `needs-stakeholder-input` and
writes a summary of what the team cannot resolve. Ralph stops and the
user engages directly.

### Amendment Issues

If during design or review, cross-epic inconsistency or PRD gaps are
discovered, the coordinator creates a `type:amendment` issue:

- Targeting `pipeline:design` for design inconsistencies
- Targeting `pipeline:review` for PRD gaps

The amendment issue enters the pipeline at the appropriate stage and
follows its own review cycle. This is a lightweight corrective path,
not a full re-design.

### Re-Decompose (Safety Valve)

If the design reveals the epic's scope is fundamentally wrong (missing
concerns, overlapping with another epic, needs splitting), the
coordinator sends the epic back to `pipeline:decompose` with a comment
explaining why. The roadmap needs updating and re-review. This is a
safety valve, not a common path.

## Implement Phase Sub-States

The implement phase uses a single `pipeline:implement` label throughout.
Sub-state is tracked via issue comments. Task issues live in component
repos (not the docs repo). The review cycle is built into the phase —
there is no separate verify phase.

### Implement Team (dynamic per task)

The coordinator assembles the team dynamically based on what the task
touches. The implementation engineer is determined by the component
repo's stack. The review team is assembled based on what the PR changes.

**Production:**

| Agent | When | Role |
|-------|------|------|
| engineer-dotnet | Task in .NET repo | Implementation |
| engineer-python | Task in Python repo | Implementation |
| engineer-angular | Task in Angular/TS repo | Implementation |
| engineer-typescript | Task in Node/TS repo | Implementation |

**Review (dynamic — coordinator reads PR diff to determine team):**

| Agent | When | Role |
|-------|------|------|
| engineer-[stack] (peer) | Always | Code quality, stack patterns, test quality, codebase consistency |
| architect | API, integration, shared concerns | Design conformance, cross-epic integration, pattern consistency |
| frontend-architect | UI components | Component architecture, state management, design system, performance |
| ux-architect | User-facing flows | Accessibility, interaction patterns, UX consistency |
| database-engineer | Data/schema changes | Query efficiency, migration safety, schema conformance |
| devops-engineer | Infrastructure/CI | Deployment config, environment handling, monitoring |
| security-reviewer | Auth, user input, external integrations | OWASP, injection, auth/authz, secrets, input validation |
| spec-compliance | Any PRD-linked task (final gate) | Acceptance criteria, design conformance, traceability |

**Lightweight path:** Not every task needs every reviewer. The coordinator
assesses the PR scope and assembles the minimum viable review team. A
small backend fix may only need peer engineer + architect. A full-stack
feature needs the wider team.

### Sub-State Machine

| Sub-state | Detected by | Next action |
|-----------|------------|-------------|
| Task created (no agent comments) | No agent comments, unclaimed | Coordinator dispatches engineer |
| "claimed by [session]" | Claim comment | Skip — engineer is working |
| "implementation complete, PR ready for review" | Engineer comment | Coordinator assembles + dispatches review team |
| "PR under review" | Coordinator comment | Reviewers working |
| "PR reviewed, N concerns raised" | Reviewer PR comments | Coordinator routes concerns to engineer |
| "PR reviewed, N concerns addressed — re-review requested" | Engineer comment | Coordinator re-dispatches review team |
| "PR reviewed, approved" | All reviewers approve | Merge PR, advance task to `pipeline:done` |
| "escalated to stakeholder" | Coordinator comment (3+ cycles) | If interactive: engage user. If Ralph: stop |
| "blocked: amendment #NNN" | Engineer comment | Skip until amendment resolved |

### CI Gate

CI must pass before the review cycle begins and after each round of
addressing concerns. Build + test + lint + type checks must all be green.
The engineer runs these locally before creating the PR. GitHub Actions
runs them again on the PR. If CI fails, the review team does not engage.

### PR Review Cycle

Same mechanism as every other phase:

1. Engineer creates PR (NOT draft, CI green)
2. Coordinator assembles review team based on PR scope
3. Reviewers leave specific, actionable PR comments referencing the
   standard they check against (design doc, PRD criterion, codebase
   pattern, security rule)
4. Coordinator routes concerns to engineer
5. Engineer addresses concerns, CI passes again, requests re-review
6. Repeat until all approve or circuit breaker triggers
7. On approval: coordinator merges PR (squash + delete branch)

### Circuit Breaker

Same pattern as all other phases. After 3 review cycles without all
reviewers approving, the coordinator escalates:
- Adds `needs-stakeholder-input` label to the task issue
- Writes a summary of unresolved concerns
- Engineer moves to other unblocked tasks

### Backward Transitions (Amendment Issues)

When implementation reveals gaps in upstream documents, the engineer
creates a `type:amendment` issue in the docs repo:

- `pipeline:design` for design/architecture gaps
- `pipeline:review` for PRD gaps

The engineer adds `blocked` label to the component task issue and
moves to other unblocked tasks. When the amendment is resolved
upstream (PR merged), the `blocked` label is removed and the task
re-enters the ready pool.

### Concurrency

Multiple tasks can be implemented concurrently. Coordination:

- **Claimed labels** prevent two sessions grabbing the same task
- **Dependency graph** from design phase determines task readiness —
  tasks with unmet dependencies are not dispatched
- **Branch-per-task** — each task works on its own feature branch
- **Rebase before merge** — incorporate other merged work
- Engineers rebase frequently during same-repo concurrent work

### Epic Completion

When all tasks for an epic reach `pipeline:done`:

1. Coordinator verifies all tasks complete and merged
2. Final integration check — build + test across all affected repos
3. Epic issue updated: "All tasks complete. Implementation done."
4. Epic advances to `pipeline:deliver`
5. If integration issues found, coordinator creates fix tasks at
   `pipeline:implement`

## Forward Transitions

### review → decompose
- All PRDs reviewed and approved by review team
- No outstanding PR comments needing stakeholder input
- PR merged to main

### decompose → design
- Roadmap document produced and merged (`docs/planning/`)
- Epic issues created in docs repo at `pipeline:design`
- Each epic references its source PRDs
- Dependencies between epics documented
- Initiative labels applied

### design → implement
- Design doc(s) approved and merged via PR
- Requirements traceability complete (spec-compliance validated)
- Cross-epic consistency verified (architect validated)
- Tasks created in component repos at `pipeline:implement`
- Each task has scope, acceptance criteria, and quality gates from design
- Epic issue updated with task links

### implement → deliver
- All tasks for the epic reviewed, approved, and merged
- CI green across all affected repos
- Final integration check passes
- Epic issue updated with completion status

### deliver → done
- E2E tests pass
- Documentation updated
- Release completed

## Backward Transitions (Feedback Loops)

Any downstream agent can escalate upstream when they find gaps. The mechanism:

1. Create a GitHub Issue: `type:amendment` with the upstream pipeline label
   and `blocked` label
2. Add `needs-stakeholder-input` if human input is required
3. Cross-reference the blocked issue
4. Add `blocked` label to the original issue

### Resolving a Blocker

1. Upstream agent picks up the amendment issue
2. Amends the document (branch + PR + merge)
3. Closes the amendment issue
4. Removes `blocked` from the original issue
5. Original issue resumes

### Loop Guard

After 3 backward transitions on the same issue, escalate to human:
add `needs-stakeholder-input` with a summary of what's been bouncing.

## Orchestration Priority

1. Resolve amendment/blocker issues (unblock other work)
2. Complete pending reviews (implementation PR reviews)
3. Continue in-progress work
4. Start highest-priority unblocked items
5. Architecture/design work
6. Product work (PRD creation, review)
7. Planning (decompose)
8. Repo provisioning
9. Release coordination

Skip rules:
- `blocked` label → skip until blocker resolved
- `needs-stakeholder-input` → skip, report to user
- `claimed:*` label → skip, another session is working on it

## State Update Protocol

After every meaningful action:
1. Update GitHub Issue label to reflect new stage
2. Update `[DOCS_REPO]/STATUS.md`
3. Update `[DOCS_REPO]/active-work/` epic file if applicable
4. Commit: `status: [action summary] on #[issue]`
