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

### What You Get

```
workspace/                       ← you started here
├── .claude/                     ← agents, skills, hooks, rules
├── CLAUDE.md                    ← operating manual
└── [project]-docs/              ← docs repo (git repo, all project state)
    ├── STATUS.md                ← project heartbeat
    ├── repos.yaml               ← repo registry
    ├── active-work/             ← session logs
    ├── scripts/                 ← ralph.sh (autonomous loop)
    └── docs/
        ├── discovery/           ← vision, context, supporting materials
        ├── prd/                 ← product requirement documents
        ├── architecture/        ← system designs + ADRs (later)
        ├── design/              ← UX + impl design (later)
        └── conventions/         ← commit + branching standards
```

### Step 3: Write Your PRDs

This is manual, creative work — you and AI in the IDE. Write your
product requirements and vision docs:

- **PRDs** → `[project]-docs/docs/prd/`
- **Vision, context, research** → `[project]-docs/docs/discovery/`

Templates are available in `docs/prd/templates/` and `docs/discovery/templates/`.

### Step 4: Submit for Review

When your PRDs are ready:

```
/submit-prds
```

This creates a branch, PR, and issue — handing off to the autonomous
review pipeline.

### Step 5: Review Cycle

Start the autonomous review loop:

```bash
cd [workspace-root]
./[project]-docs/scripts/ralph.sh
```

Ralph runs the review team (product-manager + architect). When they need
your input, Ralph stops. Start an interactive Claude session — the
stakeholder facilitator walks you through the findings. Restart Ralph
for re-review. Cycle continues until PRDs are approved.

See `GUIDE.md` for detailed step-by-step instructions.

## Pipeline

```
Discovery (manual) → Review → Decompose → Design → Implement ↔ Verify → Deliver → Done
```

Currently implemented: **Setup + Discovery + Review**.

## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Operating manual — workspace layout, pipeline, agents, state |
| `STATUS.md` | Project heartbeat — current work, blockers, progress |
| `repos.yaml` | Repository registry — topology and dependencies |
| `GUIDE.md` | Step-by-step user guide |

## Agents

| Agent | Role |
|-------|------|
| `product-manager` | PRD completeness, cross-PRD consistency, scope discipline |
| `architect` | Technical feasibility, NFR assessment, risk identification |
| `frontend-architect` | Frontend feasibility, performance budgets, accessibility |
| `stakeholder-facilitator` | Mediates review findings with user, edits docs, handles git |

## State Architecture

| Layer | What | Where | Shared? |
|-------|------|-------|---------|
| **Project state** | STATUS.md, session logs, PRDs, issues | Docs repo (git) | Yes |
| **Auto memory** | Claude's own learnings and patterns | `~/.claude/projects/` | No (machine-local) |

Project state is the source of truth. See CLAUDE.md for full details.
