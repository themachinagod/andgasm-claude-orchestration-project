# [PROJECT_NAME]

> Docs repo for the project. No application code here. PRDs, architecture,
> design, coordination state, and pipeline tracking. Code lives in component
> repos listed in `[DOCS_REPO]/repos.yaml`.

## Workspace Layout

```
workspace/
├── .claude/              ← agents, skills, hooks, rules (moved from docs repo at init)
├── CLAUDE.md             ← this file (moved from docs repo at init)
├── [DOCS_REPO]/          ← docs repo (git repo — all project state)
│   ├── STATUS.md
│   ├── repos.yaml
│   ├── active-work/
│   └── docs/
│       ├── discovery/    ← vision, context, supporting materials
│       ├── prd/          ← product requirement documents
│       ├── planning/     ← roadmap + epic decomposition
│       ├── architecture/ ← system designs + ADRs (later)
│       ├── design/       ← UX + implementation design (later)
│       └── conventions/  ← commit + branching standards
├── [component-repo]/     ← implementation code (created later)
└── [component-repo]/     ← implementation code (created later)
```

You operate from the workspace root. Use `cd` only for git operations.

## Session Identity

Every Claude instance receives a unique session ID at startup from the
`on-session-start.sh` hook. The ID appears in the hook output as:

```
Session ID: interactive-YYYYMMDDTHHMMSS-PID
```

For Ralph sessions, the ID is passed in the prompt as:

```
Session ID: ralph-YYYYMMDDTHHMMSS-PID
```

**Your session ID is your identity for the entire session.** Use it for:
- Claiming issues: `claimed:[your-session-id]` label
- STATUS.md Active Sessions table entries
- Any state that needs to be attributed to this specific session

Two Claude instances running concurrently will have different session
IDs. Never assume you are the same session as a previous or concurrent
instance — always use the session ID from YOUR startup output.

## First Action on Every Session

Note your session ID from the startup hook output, then run `/orient`
to understand current project state before any other work.

Or manually:
1. Read `[DOCS_REPO]/STATUS.md` for current project state
2. Read `[DOCS_REPO]/repos.yaml` for the repo registry and local paths
3. Check `[DOCS_REPO]/active-work/` for in-progress epics
4. Check GitHub Issues:
   ```bash
   cd [DOCS_REPO] && gh issue list --state open --json number,title,labels && cd ..
   ```
5. For each component repo:
   ```bash
   cd [component-repo] && gh pr list && cd ..
   ```

## Pipeline

Issues flow through these stages. Never skip stages.

```
Discovery (manual) → Review → Decompose → Design → Implement → Deliver → Done
```

| Stage | Label | Owner | What happens |
|-------|-------|-------|-------------|
| Discovery | (manual) | User | Write PRDs and vision docs in IDE |
| Review | `pipeline:review` | Review Team + Stakeholder Facilitator | PRD analysis + stakeholder facilitation cycle |
| Decompose | `pipeline:decompose` | project-coordinator + product-manager + architect | PRDs → epics + roadmap |
| Design | `pipeline:design` | coordinator + architect + specialists (dynamic) | Architecture, design, task breakdown |
| Implement | `pipeline:implement` | coordinator + engineer-[stack] + dynamic review team | Per-task coding + specialist PR review |
| Deliver | `pipeline:deliver` | e2e-test-engineer + tech-writer + release-manager | E2E, docs, release |
| Done | `pipeline:done` | — | Completed |

### Pipeline Teams

| Stage | Team | Primary | Sign-off | Escalation |
|-------|------|---------|----------|------------|
| Review | product-manager + architect | orchestrator | stakeholder (via facilitator) | Always — facilitation loop |
| Decompose | product-manager + architect + coordinator | coordinator | PM + architect (PR review) | Stakeholder if 3+ PR review cycles |
| Design | coordinator + architect + spec-compliance + specialists (dynamic) | coordinator | architect + spec-compliance + specialists (PR review) | Stakeholder if 3+ PR review cycles |
| Implement | coordinator + engineer-[stack] + dynamic review team | coordinator | spec-compliance (final gate) + architect + specialists (PR review) | Stakeholder if 3+ PR review cycles |

### Review Phase (Detail)

The review phase has a sub-state machine tracked via issue comments.
The `pipeline:review` label stays throughout. The only secondary label
is `needs-stakeholder-input` (signals Ralph to stop).

**Sub-states:**

| Sub-state | Signal | Next action |
|-----------|--------|-------------|
| Needs first review | No agent comments on issue | Review Team reviews |
| Needs stakeholder input | Agent comment: "N items need stakeholder input" | Facilitator engages user |
| Needs re-review | Facilitator comment: "input provided, ready for re-review" | Review Team re-reviews |
| Approved | Agent comment: "approved" | Merge PR, advance to decompose |

**Review Team:** product-manager (product completeness) + architect
(technical feasibility). Both work on the same PR, leave PR comments
for stakeholder items, fix obvious issues directly.

**Stakeholder Facilitator:** Reads review comments, synthesizes findings,
walks user through each item, edits docs based on answers, pushes changes.

**Ralph integration:** Ralph runs the review team autonomously. When
stakeholder input is needed, Ralph stops. The user starts an interactive
Claude session where the facilitator engages. After facilitation, the
user restarts Ralph for re-review.

### Decompose Phase (Detail)

The decompose phase turns approved PRDs into an actionable product roadmap
of epics. The `pipeline:decompose` label stays throughout. Sub-state is
tracked via issue comments.

**Team:**
- `project-coordinator` (primary) — process manager: delegates analysis
  to PM and architect, produces roadmap from their inputs, manages PR
  review cycle. Never writes technical or product analysis — only
  process artifacts.
- `product-manager` — product analysis: groupings, foundational product
  epics, initiative themes, PR review authority
- `architect` — technical analysis: foundational design epics,
  infrastructure epics, dependency constraints, PR review authority

**Sub-states:**

| Sub-state | Signal | Next action |
|-----------|--------|-------------|
| Needs decomposition | No agent comments on issue | Coordinator produces roadmap |
| PR under review | Coordinator: "decomposition proposed, PR ready for review" | PM + architect review PR |
| Needs revision | PM/architect PR comments with concerns | Coordinator addresses comments |
| Approved | PM + architect: "PR reviewed, approved" | Merge PR, create epic issues |
| Escalated | Coordinator: "escalated to stakeholder" (3+ cycles) | User engages |

**Circuit breaker:** After 3 PR review cycles without PM and architect
approval, the coordinator adds `needs-stakeholder-input` and writes a
summary of unresolved concerns. Ralph stops and the user resolves directly.

**Outputs:**
- Roadmap document in `[DOCS_REPO]/docs/planning/roadmap.md` (includes
  foundational epics at Level 0, product epics, and technical/infra epics)
- Epic issues in docs repo at `pipeline:design`
- Initiative labels applied to epic issues (e.g., `initiative:auth`)

**Ralph integration:** Ralph runs the coordinator autonomously. The PR
review cycle (PM + architect reviewing with PR comments) happens within
the same session (autonomous, no user needed). Only if the circuit
breaker triggers does Ralph stop for stakeholder input.

### Design Phase (Detail)

The design phase produces architecture docs, ADRs, and design artifacts
for each epic, then decomposes into implementation tasks. The
`pipeline:design` label stays throughout. Sub-state is tracked via
issue comments.

**Team (dynamic per epic):**
- `project-coordinator` (primary) — process manager: assembles team,
  delegates all design production to sub-agents, collates outputs,
  manages PR review cycle, decomposes into tasks (with engineer input
  on task boundaries)
- `architect` (always) — system design, cross-epic consistency, ADRs,
  codebase patterns
- `spec-compliance` (if PRD linkage) — PRD coverage + cross-document
  consistency reviewer
- Specialists (dynamic from repos.yaml) — stack-specific design +
  codebase review (frontend-architect, ux-architect, engineer-dotnet,
  engineer-python, engineer-angular, engineer-typescript,
  database-engineer, devops-engineer)

**Sub-states:**

| Sub-state | Signal | Next action |
|-----------|--------|-------------|
| Needs design | No agent comments on issue | Coordinator assesses + assembles team |
| Spike needed | Coordinator: "spike needed: [unknowns]" | Coordinator runs time-boxed spike |
| PR under review | Coordinator: "design proposed, PR ready for review" | Design team reviews PR |
| Needs revision | Reviewer PR comments with concerns | Coordinator addresses comments |
| Approved | All reviewers: "PR reviewed, approved" | Merge PR, create tasks |
| Tasks created | Coordinator: "design complete, N tasks created" | Advance epic |
| Escalated | Coordinator: "escalated to stakeholder" (3+ cycles) | User engages |
| Needs re-decompose | Coordinator: "needs-redecompose: [reason]" | Back to decompose |

**Circuit breaker:** After 3 PR review cycles without convergence,
the coordinator adds `needs-stakeholder-input` and writes a summary
of unresolved concerns. Ralph stops and the user resolves directly.

**Outputs:**
- Design doc(s) in `[DOCS_REPO]/docs/architecture/[epic-name]/` (merged PR)
- ADRs in `[DOCS_REPO]/docs/architecture/decisions/`
- API contracts, schema designs, UX specs as applicable
- Task issues in component repos at `pipeline:implement`

**Ralph integration:** Ralph picks up epics at `pipeline:design` in
dependency order (Level 0 first). Each Ralph session: orchestrator
dispatches coordinator, coordinator drives one epic through the full
design cycle (assessment, team assembly, design production, PR review,
task decomposition). Only if the circuit breaker triggers does Ralph
stop for stakeholder input.

## Available Skills

### Pipeline
- `/submit-prds` — bridge from manual discovery to pipeline (branch, PR, issue)
- `/orchestrate` — pipeline orchestrator (reads state, dispatches agent teams for review, decompose, and design stages)

### Utility
- `/orient` — situational report (project state, issues, PRs, recommendations)
- `/initialise-workspace` — bootstrap a new project workspace (global skill)
- `/upgrade-workspace` — upgrade tooling to latest orchestrator template (preserves project content)

## Available Agents

### Review Phase
- `product-manager` — PRD completeness, consistency, cross-PRD conflicts, scope
- `architect` — technical feasibility, NFR realism, hidden complexity, risks
- `frontend-architect` — frontend feasibility (when PRD has UI components)
- `stakeholder-facilitator` — mediates between review findings and user

### Decompose Phase
- `project-coordinator` — process manager: delegates analysis to PM and architect, produces roadmap from their inputs, manages PR review cycle
- `product-manager` — product analysis: groupings, foundational product epics, initiative themes, PR review
- `architect` — technical analysis: foundational design epics, infrastructure epics, dependency identification, PR review

### Design Phase
- `project-coordinator` — process manager: assembles team, delegates all design to sub-agents, collates outputs, manages PR review cycle, task decomposition (with engineer input)
- `architect` — system design, cross-epic consistency, ADRs, codebase patterns
- `spec-compliance` — PRD coverage (vertical) + cross-document consistency (horizontal) reviewer
- `frontend-architect` — component architecture, state management, performance budgets (UI epics)
- `ux-architect` — user flows, interaction design, accessibility (UX epics)
- `engineer-dotnet` — .NET design + codebase review (if .NET repos involved)
- `engineer-python` — Python design + codebase review (if Python repos involved)
- `engineer-angular` — Angular/TS design + codebase review (if Angular repos involved)
- `engineer-typescript` — TypeScript/Node.js design + codebase review (if Node/TS repos involved)
- `database-engineer` — schema design, query patterns, migrations (if data concerns)
- `devops-engineer` — CI/CD, deployment, monitoring (if infra concerns)

### Implement Phase
- `project-coordinator` — dispatch tasks, assemble review teams, track epic completion, integration verification
- `engineer-dotnet` — .NET implementation + peer review
- `engineer-python` — Python implementation + peer review
- `engineer-angular` — Angular/TS implementation + peer review
- `engineer-typescript` — Node/TS implementation + peer review
- `architect` — implementation PR review: design conformance, cross-epic integration, pattern consistency
- `frontend-architect` — implementation PR review: component architecture, state management, design system
- `ux-architect` — implementation PR review: accessibility, interaction patterns, UX consistency
- `database-engineer` — implementation PR review: query efficiency, migration safety, schema conformance
- `devops-engineer` — implementation PR review: deployment config, environment handling, monitoring
- `security-reviewer` — implementation PR review: OWASP, injection, auth/authz, secrets, input validation
- `spec-compliance` — implementation PR review (final gate): acceptance criteria, design conformance, traceability

### Later Phases (not yet ported)
- `e2e-test-engineer`, `release-manager`, `tech-writer` — deliver

## State

### Project State (shared, git-tracked)

| Source | Purpose |
|--------|---------|
| `[DOCS_REPO]/STATUS.md` | Project heartbeat — current work, blockers, progress |
| `[DOCS_REPO]/repos.yaml` | Repo registry — topology, paths, dependencies |
| `[DOCS_REPO]/active-work/` | Session logs — decisions, progress, next steps |
| `[DOCS_REPO]/docs/` | PRDs, architecture, design, conventions |
| GitHub Issues | Work items with pipeline labels |
| GitHub PRs | Doc/code changes with review comments |

This is the source of truth. If it's not here, it didn't happen.

### Auto Memory (local, Claude-managed)

Claude maintains its own memory at `~/.claude/projects/<project>/memory/`.
Machine-local, not shared via git, not the source of truth.
If a learning matters to the project, promote it to CLAUDE.md or
`docs/conventions/`.

## Cross-Repo Rules

- Epics and stories tracked in the docs repo (GitHub Issues)
- Implementation tasks pushed to component repo Issues
- PRDs, architecture, UX specs live in the docs repo
- Code changes happen in component repos (`cd` for git ops only)
- `[DOCS_REPO]/STATUS.md` aggregates state across ALL repos
- Dependency order: check `[DOCS_REPO]/repos.yaml` `depends_on`

## Git Conventions

See `[DOCS_REPO]/docs/conventions/` for:
- Commit conventions (`commits.md`)
- Branching strategy (`branching.md`)

### What Goes on Branches (PR required)
All content changes: PRDs, architecture docs, UX specs, epic files, code.

### What Goes Direct to Main
Operational state only: STATUS.md updates, session log entries.

## Autonomous Operation (Ralph)

Ralph (`scripts/ralph.sh`) runs Claude sessions in a loop. Each session:
1. Runs `/orchestrate`
2. Completes one unit of work (review, decompose, or whatever stage is active)
3. Updates all state
4. Exits

Ralph stops when:
- `needs-stakeholder-input` label detected (user must engage)
- All pipeline issues are done
- 3 consecutive failures

After Ralph stops for stakeholder input:
1. User starts interactive Claude session
2. Orchestrator detects state and engages user (facilitator for review,
   direct discussion for decompose concerns)
3. After resolution, user restarts Ralph

## If You Don't Know What To Do

1. Run `/orient`
2. Check `[DOCS_REPO]/STATUS.md` for current state
3. Check GitHub Issues for actionable items
4. If nothing actionable, update STATUS.md and report
