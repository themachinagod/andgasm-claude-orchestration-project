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
├── [component-repo]/     ← implementation code (created later)
└── [component-repo]/     ← implementation code (created later)
```

You operate from the workspace root. Use `cd` only for git operations.

## State

### Project State (shared, git-tracked)

| Source | Purpose |
|--------|---------|
| `[DOCS_REPO]/STATUS.md` | Project heartbeat — current work, blockers, progress |
| `[DOCS_REPO]/repos.yaml` | Repo registry — topology, paths, dependencies |
| `[DOCS_REPO]/active-work/` | Session logs — decisions, progress, next steps |
| `[DOCS_REPO]/docs/` | PRDs, architecture, design, conventions |
| GitHub Issues | Work items with labels |
| GitHub PRs | Code/doc changes with review comments |
| GitHub Project | Cross-repo tracking and visibility |

This is the source of truth. If it's not here, it didn't happen.

### Auto Memory (local, Claude-managed)

Claude maintains its own memory at `~/.claude/projects/<project>/memory/`.
Machine-local, not shared via git, not the source of truth.
If a learning matters to the project, promote it to CLAUDE.md,
`.claude/rules/`, or `docs/conventions/`.

## Git Conventions

See `[DOCS_REPO]/docs/conventions/` for:
- Commit conventions (`commits.md`)
- Branching strategy (`branching.md`)

All work happens on branches. PRs to main. Squash merge.
Every PR references a GitHub Issue.

## Skills

### Available
- `/initialise-workspace` — bootstrap a new project workspace (global skill)
