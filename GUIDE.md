# User Guide

Step-by-step guide to using the project orchestrator. This evolves as
phases are built and tested.

## Phase: Setup

### Prerequisites

- Claude Code installed
- GitHub CLI (`gh`) authenticated (`gh auth login`)
- Git configured

### Install the workspace initializer (once per machine)

```bash
mkdir -p ~/.claude/skills/initialise-workspace
cp .claude/skills/initialise-workspace/SKILL.md ~/.claude/skills/initialise-workspace/SKILL.md
```

### Create a new workspace

1. Create an empty directory and open Claude Code:

```bash
mkdir my-project && cd my-project
claude
```

2. Run `/initialise-workspace`

3. Answer the questions:
   - **Project name** (required) — e.g. "northwind"
   - **Description** (required) — one paragraph, what are you building
   - **Audience** (optional) — who is this for
   - **Tech preferences** (optional) — e.g. ".NET APIs, Angular UI"
   - **Constraints** (optional) — timeline, compliance, integrations
   - **Visibility** (optional) — default: private

4. The skill creates your workspace:
   - Docs repo cloned from template
   - `.claude/` and `CLAUDE.md` moved to workspace root
   - All files configured with your project details
   - Labels synced to docs repo
   - GitHub Project created

### After setup, your workspace looks like:

```
my-project/
├── .claude/
├── CLAUDE.md
└── northwind-docs/
    ├── STATUS.md
    ├── repos.yaml
    ├── docs/
    │   ├── discovery/       ← put vision docs here
    │   ├── prd/             ← put PRDs here
    │   └── conventions/
    └── ...
```

---

## Phase: Discovery (manual)

Write your PRDs and vision documents. This is you and AI in the IDE —
creative, iterative, take as long as you need.

### Where to put things

| What | Where |
|------|-------|
| Product vision, context, research, competitor notes | `[project]-docs/docs/discovery/` |
| Detailed requirements (PRDs) | `[project]-docs/docs/prd/` |

PRDs don't need to follow a rigid template. Write enough detail to
describe what you're building, why, and for whom.

### When you're done

Run `/submit-prds` to hand off to the pipeline. *(Not yet built.)*

---

## Later phases (not yet built)

- **Review** — autonomous review of PRDs, guided user facilitation
- **Decompose** — PRDs → epics + roadmap
- **Design** — per-epic architecture, UX, task breakdown
- **Implement** — per-task coding
- **Verify** — code review, testing, security, spec compliance
- **Deliver** — E2E, docs, release

Each phase will be added to this guide as it's designed and tested.
