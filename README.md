# Project Orchestrator Template

Template for AI-orchestrated multi-repo development — docs, PRDs,
pipeline state, and Claude Code agents for autonomous software delivery.

This template creates the **docs repo** for your project. It holds all
documentation, coordination state, and pipeline tracking. Component
repos (APIs, UIs, shared libs) are created later as the project evolves.

## Getting Started

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- Git configured

### Step 1: Install the Workspace Initializer (once per machine)

```bash
mkdir -p ~/.claude/skills/initialise-workspace
cp .claude/skills/initialise-workspace/SKILL.md ~/.claude/skills/initialise-workspace/SKILL.md
```

### Step 2: Create a New Workspace

From an empty directory:

```bash
mkdir my-project && cd my-project
claude
```

Then run `/initialise-workspace`. The skill will:

1. Detect your GitHub account from `gh auth status`
2. Ask for project name, description, and optional context
3. Create the docs repo from this template
4. Move `.claude/` and `CLAUDE.md` to workspace root
5. Configure all files with your project details
6. Sync pipeline labels to the docs repo
7. Create a GitHub Project for tracking

### What You Get

```
workspace/                       ← you started here
├── .claude/                     ← agents, skills, hooks, rules
├── CLAUDE.md                    ← operating manual
└── [project]-docs/              ← docs repo (git repo, all project state)
    ├── STATUS.md                ← project heartbeat
    ├── repos.yaml               ← repo registry
    ├── active-work/             ← session logs
    └── docs/
        ├── discovery/           ← vision, context, supporting materials
        ├── prd/                 ← product requirement documents
        ├── architecture/        ← system designs + ADRs (later)
        ├── design/              ← UX + impl design (later)
        ├── planning/            ← roadmap + epic briefs (later)
        └── conventions/         ← commit + branching standards
```

### Step 3: Write Your PRDs

This is manual, creative work — you and AI in the IDE. Write your
product requirements and vision docs:

- **PRDs** → `[project]-docs/docs/prd/`
- **Vision, context, research** → `[project]-docs/docs/discovery/`

Iterate as much as needed. There's no template to follow — write
enough detail to describe what you're building and why.

### Step 4: Submit for Review (coming soon)

When your PRDs are ready, `/submit-prds` will create a branch, PR,
and issue — handing off to the autonomous pipeline. This skill is
not yet built.

## Pipeline Vision

```
Discovery (manual) → Review → Decompose → Design → Implement ↔ Verify → Deliver
```

Currently implemented: **Setup (init) + Discovery (manual)**.
Further phases are being designed and built incrementally.

## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Operating manual — workspace layout, rules, state architecture |
| `STATUS.md` | Project heartbeat — current work, blockers, progress |
| `repos.yaml` | Repository registry — topology and dependencies |
| `GUIDE.md` | Step-by-step user guide |

## State Architecture

| Layer | What | Where | Shared? |
|-------|------|-------|---------|
| **Project state** | STATUS.md, session logs, PRDs, issues | Docs repo (git) | Yes |
| **Auto memory** | Claude's own learnings and patterns | `~/.claude/projects/` | No (machine-local) |

Project state is the source of truth. See CLAUDE.md for full details.
