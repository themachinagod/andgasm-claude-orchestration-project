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
│       ├── architecture/ ← system designs + ADRs (later)
│       ├── design/       ← UX + implementation design (later)
│       └── conventions/  ← commit + branching standards
├── [component-repo]/     ← implementation code (created later)
└── [component-repo]/     ← implementation code (created later)
```

You operate from the workspace root. Use `cd` only for git operations.

## First Action on Every Session

Run `/orient` to understand current project state before any other work.

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
Discovery (manual) → Review → Decompose → Design → Implement ↔ Verify → Deliver → Done
```

| Stage | Label | Owner | What happens |
|-------|-------|-------|-------------|
| Discovery | (manual) | User | Write PRDs and vision docs in IDE |
| Review | `pipeline:review` | Review Team + Stakeholder Facilitator | PRD analysis + stakeholder facilitation cycle |
| Decompose | `pipeline:decompose` | project-coordinator | PRDs → epics + roadmap |
| Design | `pipeline:design` | architect + frontend-architect + ux-architect | Architecture, UX, task breakdown |
| Implement | `pipeline:implement` | engineer-[stack] | Per-task coding |
| Verify | `pipeline:verify` | code-reviewer + test-engineer + security-reviewer + spec-compliance | Review pipeline |
| Deliver | `pipeline:deliver` | e2e-test-engineer + tech-writer + release-manager | E2E, docs, release |
| Done | `pipeline:done` | — | Completed |

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

## Available Skills

### Pipeline
- `/submit-prds` — bridge from manual discovery to pipeline (branch, PR, issue)
- `/orchestrate-review` — focused review-phase orchestrator (reads state, dispatches agents)

### Utility
- `/orient` — situational report (project state, issues, PRs, recommendations)
- `/initialise-workspace` — bootstrap a new project workspace (global skill)

## Available Agents

### Review Phase
- `product-manager` — PRD completeness, consistency, cross-PRD conflicts, scope
- `architect` — technical feasibility, NFR realism, hidden complexity, risks
- `frontend-architect` — frontend feasibility (when PRD has UI components)
- `stakeholder-facilitator` — mediates between review findings and user

### Later Phases (not yet ported)
- `ux-architect` — user flows, interaction design, accessibility
- `project-coordinator` — epic decomposition, task creation
- `engineer-*` — stack-specific implementation
- `code-reviewer`, `security-reviewer`, `test-engineer`, `spec-compliance` — verify
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
1. Runs `/orchestrate-review`
2. Completes one unit of work
3. Updates all state
4. Exits

Ralph stops when:
- `needs-stakeholder-input` label detected (user must engage)
- All review issues are done
- 3 consecutive failures

After Ralph stops for stakeholder input:
1. User starts interactive Claude session
2. Orchestrator detects state, invokes stakeholder-facilitator
3. Facilitator walks through findings with user
4. After facilitation, user restarts Ralph

## If You Don't Know What To Do

1. Run `/orient`
2. Check `[DOCS_REPO]/STATUS.md` for current state
3. Check GitHub Issues for actionable items
4. If nothing actionable, update STATUS.md and report
