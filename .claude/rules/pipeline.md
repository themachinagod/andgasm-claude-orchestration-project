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
| Implement | `pipeline:implement` | Per-task coding + specialist PR review in component repos |
| Deliver | `pipeline:deliver` | E2E, docs, release |
| Done | `pipeline:done` | Completed and delivered |

## Structured State Markers

All phases use issue comments to track sub-state. Every state transition
comment MUST include a structured marker:

```
**Status:** [state text]
```

The orchestrator detects state by finding the latest comment containing
`**Status:**` and reading the text that follows. Rules:

1. Every state transition comment MUST include `**Status:**` as the
   last meaningful line
2. The status text must match a defined sub-state string for the phase
3. Additional context (summaries, lists) can appear above the status line
4. Agents must NOT use `**Status:**` in non-state-transition comments

This format is human-readable (renders as bold in GitHub) and
machine-parseable (prefix match, not substring search).

## CI Check Before Any PR Merge

Before merging ANY PR in ANY phase (review, decompose, design,
implement), the coordinator or orchestrator MUST verify CI is green:

```bash
gh pr checks [PR_NUMBER] --repo [repo]
```

If any required check has failed, the PR is NOT merged. Route back to
the responsible agent to fix. A PR with failing CI is never merged.

## Review Phase Sub-States

The review phase uses a single `pipeline:review` label throughout.
Sub-state tracked via structured issue comments. The only secondary
label is `needs-stakeholder-input` (signals Ralph to stop).

### Sub-State Machine

| Sub-state | Detected by (`**Status:**` marker) | Next action |
|-----------|-----------------------------------|-------------|
| Issue just created | No agent comments on issue | Review Team analyses PRDs |
| Needs stakeholder input | `**Status:** reviewed, N items need stakeholder input` | Stakeholder Facilitator engages user |
| Input provided | `**Status:** stakeholder input provided, ready for re-review` | Review Team re-reviews (full, not just prior) |
| Approved | `**Status:** approved` | Check CI, merge PR, advance to `pipeline:decompose` |

### Review Team Behavior

The review team (product-manager + architect) analyses ALL PRDs holistically:

1. Read every PRD and discovery doc
2. Product review: completeness, consistency, gaps, scope, success criteria
3. Technical review: feasibility, hidden complexity, NFR realism, risks
4. Fix obvious issues directly (push to PR branch)
5. Leave PR comments for items needing stakeholder decisions
6. Update the issue with structured comment including `**Status:**` marker

### Stakeholder Facilitator Behavior

The facilitator mediates between review findings and the user:

1. Read all open PR review comments and prior cycle context
2. Group and prioritize: conflicts > gaps > suggestions
3. Walk user through each finding conversationally
4. Edit PRD files based on answers, push to PR branch
5. Update issue with `**Status:** stakeholder input provided, ready for re-review`
6. Remove `needs-stakeholder-input` label

## Decompose Phase Sub-States

The decompose phase uses a single `pipeline:decompose` label throughout.
Sub-state tracked via structured issue comments. The `needs-stakeholder-input`
label is only added when the team cannot converge (circuit breaker).

### Decompose Team

| Agent | Role | What they do |
|-------|------|-------------|
| project-coordinator (primary) | Process manager | Delegates analysis to PM and architect, produces roadmap from their inputs (process artifact), manages PR review cycle. Never writes technical or product analysis. |
| product-manager | Product analysis + PR review | Proposes product groupings + foundational product epics, reviews roadmap PR |
| architect | Technical analysis + PR review | Identifies foundational design epics + infrastructure epics, reviews roadmap PR |

### Sub-State Machine

| Sub-state | Detected by (`**Status:**` marker) | Next action |
|-----------|-----------------------------------|-------------|
| Needs decomposition | No agent comments on issue | Coordinator delegates to PM + architect, produces roadmap |
| PR under review | `**Status:** decomposition proposed, PR ready for review` | PM + architect review the PR |
| Needs revision | PR comments with concerns | Coordinator routes concerns to owning sub-agent |
| Approved | `**Status:** PR reviewed, approved` | Check CI, merge PR, create epic issues at `pipeline:design` |
| Escalated | `**Status:** escalated to stakeholder` | If interactive: engage user. If Ralph: stop |
| Stakeholder resolved | `**Status:** stakeholder input provided` | Coordinator revises |

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
Sub-state tracked via structured issue comments. The `needs-stakeholder-input`
label is only added when the circuit breaker triggers.

### Design Team (dynamic per epic)

The coordinator assembles the team dynamically based on the epic's scope.
It reads repos.yaml, the epic, and agent descriptions to intelligently
select the right specialists — not a rigid lookup table.

- **Architect** — always present (primary design producer)
- **Spec-compliance** — present for any epic with PRD linkage
- **Specialists** — selected based on what the epic touches (frontend-
  architect, ux-architect, engineer-[stack], database-engineer,
  devops-engineer). Coordinator reads the epic scope and matches to
  agent capabilities.

**Lightweight path:** Not every epic needs the full team. The coordinator
assesses the epic's scope and assembles the minimum viable team.

### Sub-State Machine

| Sub-state | Detected by (`**Status:**` marker) | Next action |
|-----------|-----------------------------------|-------------|
| Needs design | No agent comments on issue | Coordinator assesses + assembles team |
| Spike needed | `**Status:** spike needed: [unknowns]` | Coordinator runs time-boxed spike |
| PR under review | `**Status:** design proposed, PR ready for review` | Design team reviews the PR |
| Needs revision | PR comments with concerns | Coordinator addresses PR comments |
| Approved | `**Status:** PR reviewed, approved` | Check CI, merge PR, decompose into tasks |
| Tasks created | `**Status:** design complete, N tasks created` | Advance epic |
| Escalated | `**Status:** escalated to stakeholder` | If interactive: engage user. If Ralph: stop |
| Needs re-decompose | `**Status:** needs-redecompose: [reason]` | Send back to `pipeline:decompose` |

### PR Review Cycle

The coordinator creates the design PR (NOT draft) and requests reviews
from the assembled design team. Reviewers leave PR comments:

- **Architect**: architectural quality, cross-epic integration, pattern consistency
- **Spec-compliance**: PRD coverage, cross-document consistency, terminology
- **Specialists**: stack-specific technical correctness

The coordinator routes each concern to the sub-agent who owns that
content, takes revised content back, updates the branch, and re-requests
review. Both architect and spec-compliance (when present) must approve.

### Circuit Breaker

After 3+ PR review rounds without converging, the coordinator adds
`needs-stakeholder-input` and writes a summary. Ralph stops.

### Task Decomposition (design → implement transition)

After the design PR is approved and merged, the coordinator decomposes
into implementation tasks. Before creating task issues:

1. **Verify repos exist** — for each component repo referenced in the
   design, check `gh repo view [owner/repo]`. If missing, provision
   or raise blocker.
2. **Validate dependency DAG** — ensure task dependencies form a
   directed acyclic graph. No circular dependencies. If cycle found,
   escalate to architect to re-examine task boundaries.
3. **Create task issues** in component repos at `pipeline:implement`

### Amendment Issues

If during design or review, cross-epic inconsistency or PRD gaps are
discovered, the coordinator creates a `type:amendment` issue:

- Targeting `pipeline:design` for design inconsistencies
- Targeting `pipeline:review` for PRD gaps

The amendment issue enters the pipeline at the appropriate stage and
follows its own review cycle.

### Re-Decompose (Safety Valve)

If the design reveals the epic's scope is fundamentally wrong, the
coordinator sends the epic back to `pipeline:decompose` with a comment
explaining why.

## Implement Phase Sub-States

The implement phase uses a single `pipeline:implement` label throughout.
Sub-state tracked via structured issue comments. Task issues live in
component repos (not the docs repo). The review cycle is built into
the phase — there is no separate verify phase.

The coordinator is dispatched **once per task** — same pattern as once
per epic in design. One coordinator invocation drives one task through
the full cycle.

### Implement Team (dynamic per task)

The coordinator assembles the team dynamically. It reads the repo context
(manifest files, codebase), the task scope, and agent descriptions to
intelligently select the appropriate engineer and review team. No rigid
mapping tables.

**Principles:**
- **Engineer** — coordinator reads the repo's technology indicators and
  selects the engineer whose expertise matches
- **Peer engineer** (always) — a second engineer of the same stack type
  reviews for code quality, patterns, test quality
- **Specialist reviewers** — included when the PR touches their domain.
  Coordinator reads the PR diff and matches to agent capabilities.
- **Spec-compliance** (final gate) — present for any PRD-linked task.
  Approval required before merge.
- **Lightweight path** — not every task needs every reviewer

### Sub-State Machine

| Sub-state | Detected by (`**Status:**` marker) | Next action |
|-----------|-----------------------------------|-------------|
| Task created (unclaimed) | No agent comments, no `claimed:*` label | Dispatch coordinator for this task |
| In progress | `**Status:** claimed by [session]` | Skip — engineer is working |
| PR ready | `**Status:** implementation complete, PR #NNN ready for review` | Coordinator checks CI, assembles + dispatches review team |
| Under review | `**Status:** PR under review` | Reviewers working |
| Needs changes | `**Status:** PR reviewed, N concerns raised` | Coordinator routes concerns to engineer |
| Re-review needed | `**Status:** PR reviewed, N concerns addressed — re-review requested` | Coordinator checks CI, re-dispatches review team |
| Approved | `**Status:** PR reviewed, approved` | Coordinator checks CI, merges PR, advances task |
| Escalated | `**Status:** escalated to stakeholder` | If interactive: engage user. If Ralph: stop |
| Blocked | `**Status:** blocked: amendment #NNN` | Skip — check if amendment is resolved |

### CI Gate

CI must pass before the review cycle begins and after each round of
addressing concerns. The coordinator verifies via `gh pr checks` before
assembling the review team and before merging.

### PR Review Cycle

Same mechanism as every other phase:

1. Engineer creates PR (NOT draft, CI green)
2. Coordinator reads PR diff, reads agent descriptions, assembles
   review team based on what the PR touches
3. Reviewers leave specific, actionable PR comments referencing the
   standard they check against
4. Coordinator routes concerns to engineer
5. Engineer addresses concerns, CI passes again, requests re-review
6. Repeat until all approve or circuit breaker triggers
7. On approval: coordinator checks CI, merges PR (squash + delete branch)

### Circuit Breaker

After 3 review cycles without all reviewers approving, the coordinator
escalates: adds `needs-stakeholder-input` label, writes summary.

### Backward Transitions (Amendment Issues)

When implementation reveals gaps in upstream documents, the engineer
creates a `type:amendment` issue in the docs repo:

- `type:amendment,pipeline:design,blocker` for design/architecture gaps
- `type:amendment,pipeline:review,blocker` for PRD gaps

The engineer adds `blocked` label to the component task issue and
moves to other unblocked tasks.

### Amendment Lifecycle Tracking

When the orchestrator encounters a blocked task, it checks whether the
blocking amendment is still open:

```bash
gh issue view [AMENDMENT_NUMBER] --repo [docs-repo] --json state
```

If the amendment is closed (resolved), the orchestrator removes the
`blocked` label from the task and treats it as ready.

### Concurrency

Multiple tasks can be implemented concurrently. Coordination:

- **Claimed labels** prevent two sessions grabbing the same task
- **Dependency graph** from design phase determines task readiness
- **Branch-per-task** — each task works on its own feature branch
- **Rebase before merge** — incorporate other merged work
- Engineers rebase frequently during same-repo concurrent work

### Epic Completion

When all tasks for an epic reach `pipeline:done`:

1. Orchestrator dispatches coordinator for integration check
2. Coordinator runs build + test across all affected repos
3. If passes: epic issue updated, advances to `pipeline:deliver`
4. If fails: coordinator creates fix tasks at `pipeline:implement`

## Forward Transitions

### review → decompose
- All PRDs reviewed and approved by review team
- CI green on PR
- PR merged to main

### decompose → design
- Roadmap document produced and merged (`docs/planning/`)
- CI green on PR
- Epic issues created in docs repo at `pipeline:design`
- Each epic references its source PRDs
- Dependencies between epics documented
- Initiative labels applied

### design → implement
- Design doc(s) approved and merged via PR
- CI green on PR
- Requirements traceability complete (spec-compliance validated)
- Cross-epic consistency verified (architect validated)
- Component repos verified to exist (coordinator checked)
- Task dependencies validated as DAG (no cycles)
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
   and `blocker` label
2. Add `needs-stakeholder-input` if human input is required
3. Cross-reference the blocked issue
4. Add `blocked` label to the original issue

### Resolving a Blocker

1. Upstream agent picks up the amendment issue
2. Amends the document (branch + PR + merge)
3. Closes the amendment issue
4. Removes `blocked` from the original issue
5. Original issue resumes

The orchestrator also checks blocked tasks proactively — if the blocking
amendment is closed, it removes the `blocked` label automatically.

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
- `blocked` label → skip until blocker resolved (check if amendment is closed)
- `needs-stakeholder-input` → skip (Ralph) or handle (interactive), report to user
- `claimed:*` label with a different session ID → skip, another session is working on it
- `claimed:*` label matching your own session ID → stale claim from a crashed prior instance, remove and treat as unclaimed

## State Update Protocol

Every meaningful action requires two updates: the GitHub Issue (source
of truth for that work item) and STATUS.md (operational dashboard).

### GitHub Issue Update

Update the issue with a `**Status:**` marker comment (see Structured
State Markers section above).

### STATUS.md Updates (section-specific)

STATUS.md is direct-to-main (operational state, not content):

```bash
cd [DOCS_REPO]
git checkout main && git pull origin main
# Update specific STATUS.md sections
git add STATUS.md
git commit -m "status: [action summary]"
git push origin main
cd ..
```

Update the **specific section** for the event — not the whole file:

#### Session Events

| Event | Section | Action |
|-------|---------|--------|
| Session starts | Active Sessions | Add row with session ID, task, timestamp |
| Session ends normally | Active Sessions | Remove your row |
| Session detects stale entry (>4 hours) | Active Sessions | Remove stale row, unclaim the work item |

#### Task Events (Implement Phase)

| Event | Section | Action |
|-------|---------|--------|
| Task claimed | In Flight | Add row (status: "In progress") |
| PR created | In Flight | Update status to "PR created" |
| PR under review | In Flight | Update status to "Under review" |
| Review concerns raised | In Flight | Update status to "Addressing N concerns" |
| PR approved + merged | In Flight → Recently Completed | Move row. Include notes (e.g., "auth API on main"). |
| Task blocked | In Flight → Blocked | Move row with blocking reference |
| Task unblocked | Blocked → In Flight | Move row back |

#### Epic/Phase Events

| Event | Section | Action |
|-------|---------|--------|
| Epic enters design | In Flight | Add row (type: design) |
| Design approved, tasks created | In Flight → Recently Completed + In Flight | Move design to completed. Add tasks as ready. |
| All epic tasks done | In Flight → Recently Completed | Move epic to completed. Update Phase in Overview. |
| Phase transition | Project Overview | Update Phase field |

#### Watch Items

| When | Who | Action |
|------|-----|--------|
| Design change affects downstream | Architect or coordinator | Add watch item with context and "relevant until" condition |
| Cross-repo dependency met | Coordinator | Add watch item noting what's now available |
| Constraint discovered | Any agent | Add watch item with ordering/prerequisite note |
| Condition met | Any agent noticing | Remove the watch item |

#### Coordination Notes

| Event | Section | Action |
|-------|---------|--------|
| Significant decision made | Key Decisions | Add row with date and context |
| Risk identified | Risks & Concerns | Add row with severity and mitigation |
| Risk resolved | Risks & Concerns | Update status to "Resolved" or remove |

### active-work/ Updates

Update `[DOCS_REPO]/active-work/` epic file if applicable — this is
the detailed per-epic session log, separate from the STATUS.md snapshot.
