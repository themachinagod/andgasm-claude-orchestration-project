---
description: Pipeline stage definitions, transitions, and orchestration rules
globs: "**/*"
---

# Pipeline Orchestration Rules

## Pipeline Stages

Issues flow through these stages. Never skip stages.

```
Discovery (manual) → Review → Decompose → Design → Implement ↔ Verify → Deliver → Done
```

| Stage | Label | What happens |
|-------|-------|-------------|
| Discovery | (none — manual) | User writes PRDs and vision docs in IDE |
| Review | `pipeline:review` | Review team analyses PRDs, stakeholder facilitation cycle |
| Decompose | `pipeline:decompose` | PRDs → epics + roadmap |
| Design | `pipeline:design` | Architecture, UX, task breakdown per epic |
| Implement | `pipeline:implement` | Per-task coding in component repos |
| Verify | `pipeline:verify` | Code review, testing, security, spec compliance |
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
| project-coordinator (primary) | Drives the process | Invokes PM and architect, synthesizes roadmap, creates PR, manages sign-off cycle |
| product-manager | Product grouping | Proposes which PRDs form epics, initiative themes, priority ordering |
| architect | Technical analysis | Identifies technical epics, dependency constraints, ordering |

### Sub-State Machine

| Sub-state | Detected by | Next action |
|-----------|------------|-------------|
| Issue created (no agent comments) | No decompose comment from agents | Coordinator decomposes |
| "decomposition proposed, awaiting sign-off" | Latest coordinator comment | PM reviews the roadmap |
| "sign-off: approved" | Latest PM comment | Merge PR, create epic issues at `pipeline:design` |
| "sign-off: concerns — [details]" | Latest PM comment | Coordinator revises |
| "revision N — [what changed]" | Latest coordinator comment | PM re-reviews |
| "escalated to stakeholder" | Coordinator comment (3+ revision cycles) | If interactive: engage user. If Ralph: stop |
| "stakeholder input provided" | User/facilitator comment | Coordinator revises |

### PM Sign-Off

The product-manager reviews the completed roadmap and either approves or
flags concerns. This is an internal team cycle — the stakeholder is NOT
involved unless the circuit breaker triggers.

### Circuit Breaker

If the coordinator and PM cycle through 3+ revisions without converging,
the coordinator adds `needs-stakeholder-input` and writes a summary of
what the team cannot resolve. Ralph stops and the user engages directly.

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
- Architecture and/or UX design docs exist
- Design reviewed and merged
- Tasks created in component repos

### implement → verify
- Implementation complete in component repo
- Tests written and passing
- PR created

### verify → deliver
- Code review, testing, security review, spec compliance all pass
- PR merged

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
2. Complete pending reviews
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

## State Update Protocol

After every meaningful action:
1. Update GitHub Issue label to reflect new stage
2. Update `[DOCS_REPO]/STATUS.md`
3. Update `[DOCS_REPO]/active-work/` epic file if applicable
4. Commit: `status: [action summary] on #[issue]`
