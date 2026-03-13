---
description: Rules for coordinating work across multiple component repositories
globs: "**/*"
---

# Multi-Repository Coordination Rules

## Workspace Model

All work happens from a single workspace root directory:

```
workspace/
├── .claude/                  ← agents, skills, hooks, rules (static)
├── CLAUDE.md                 ← operating manual (static)
├── [DOCS_REPO]/              ← docs, status, coordination (git repo)
│   ├── STATUS.md
│   ├── repos.yaml
│   ├── active-work/
│   └── docs/
├── [component-repo]/         ← implementation code (git repo)
└── [component-repo]/         ← implementation code (git repo)
```

### Reading Content
All docs, STATUS.md, repos.yaml, and active-work files are accessible from
workspace root via the docs repo path. No `cd` needed to read or reference
any content.

### Git Operations
Git commands (checkout, commit, push, PR) must run from within the target
repo directory. Use `cd [DOCS_REPO]` or `cd [component-repo]` for git
operations, then `cd ..` to return to workspace root.

### Issue Operations
GitHub Issues live in the repo they relate to:
- Documentation/coordination issues → docs repo
- Implementation issues → component repos

### No Component Template
Component repos are plain git repos — no `.claude/` directory, no template.
The `/repo-provision` skill creates and configures them programmatically.

## Repository Registry

Always read `[DOCS_REPO]/repos.yaml` to understand repo relationships,
dependency graphs, relative paths, and build/test/lint commands before
cross-repo work.

## Dependency Ordering

When changes span multiple repos, apply in leaf-first (dependency) order:
1. Shared libraries FIRST (no dependencies)
2. APIs and services SECOND (depend on shared)
3. UIs and consumers LAST (depend on APIs and shared)

Verify each downstream repo still builds after upstream changes.

## Cross-Repo Workflow

- Epics tracked in docs repo, tasks pushed to component repos
- Each repo gets its own PR — no cross-repo PRs
- All PRs reference the docs repo epic issue
- Merge in dependency order
- Update `[DOCS_REPO]/active-work/` and `[DOCS_REPO]/STATUS.md` after component work

## State Tracking

- `[DOCS_REPO]/STATUS.md` is the project-level source of truth
- Component repo `STATUS.md` tracks repo-level state and technical notes
- Session logs go to `[DOCS_REPO]/active-work/EPIC-NNN.md`

## Context Sharing

The docs repo provides context component repos need:
- PRDs (what to build) → `[DOCS_REPO]/docs/prd/`
- UX specs (how it should look/feel) → `[DOCS_REPO]/docs/design/ux/`
- Architecture (how to structure it) → `[DOCS_REPO]/docs/architecture/`
- Conventions (coding standards) → `[DOCS_REPO]/docs/conventions/`
- Active-work (progress tracking) → `[DOCS_REPO]/active-work/`

Component repos reference these, never duplicate them.
