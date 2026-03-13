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

PRDs don't need to follow a rigid template. A template is available at
`docs/prd/templates/prd-template.md` for reference, but write enough
detail to describe what you're building, why, and for whom.

Discovery docs have a template too: `docs/discovery/templates/discovery-template.md`.

### When you're done

Run `/submit-prds` to hand off to the pipeline.

---

## Phase: Review

After submitting PRDs, the review cycle begins. This is a loop between
autonomous review and interactive stakeholder facilitation.

### How it works

```
/submit-prds → Review Team (autonomous) → Stakeholder Facilitation (you) → Re-review → ... → Approved → Merge
```

### Step 1: Submit PRDs

```
/submit-prds
```

This creates:
- A branch with your PRD and discovery files
- A PR for the review team to work on
- A GitHub Issue at `pipeline:review`

### Step 2: Start autonomous review

Run ralph.sh from the workspace root:

```bash
./scripts/ralph.sh
```

Or manually in Claude:

```
/orchestrate
```

The review team (product-manager + architect) will:
- Read all your PRDs holistically
- Fix obvious issues (formatting, consistency)
- Leave PR comments for items needing your input
- Update the issue with a summary

### Step 3: Stakeholder facilitation

Ralph stops when the review team needs your input. Start an interactive
Claude session:

```bash
claude
```

The orchestrator detects the review state and invokes the stakeholder
facilitator, which will:
- Summarize what the reviewers found
- Walk you through each item
- Discuss trade-offs and options with you
- Edit your PRDs based on your answers
- Push everything to the PR

You just answer questions. The facilitator handles all git mechanics.

### Step 4: Re-review

After facilitation, restart ralph:

```bash
./scripts/ralph.sh
```

The review team does a full re-review (not just checking prior items).
If more items surface, the cycle repeats. When everything is clean,
the PR is merged and the issue advances to `pipeline:decompose`.

### Ralph options

```bash
./scripts/ralph.sh --max-cycles 5    # limit cycles
./scripts/ralph.sh --dry-run          # preview without running
./scripts/ralph.sh --pause 30         # 30s between cycles
./scripts/ralph.sh --max-turns 50     # limit Claude turns per cycle
./scripts/ralph.sh --timeout 300      # 5-minute timeout per cycle
```

---

## Phase: Decompose

After review completes (PRDs approved and merged), the decompose phase
groups your PRDs into epics and produces a product roadmap. This is
mostly autonomous — the team works without you unless it hits a snag.

### How it works

```
Review approved → Decompose team (PM + architect + coordinator) → Roadmap → PM sign-off → Epic issues created
```

### Step 1: Automatic pickup

Ralph picks this up automatically after the review phase merges. The
orchestrator detects the issue at `pipeline:decompose` and dispatches
the decomposition team.

Or manually in Claude:

```
/orchestrate
```

### Step 2: Team produces roadmap

The decomposition team works autonomously:

- **Product-manager** analyses PRDs and proposes groupings — which PRDs
  form natural epics, what initiative themes emerge, what priority ordering
- **Architect** identifies technical epics (infra, shared libs, auth) not
  in the PRDs, and flags dependency constraints between epics
- **Coordinator** synthesizes both perspectives into a roadmap document,
  creates a branch and PR

### Step 3: PM sign-off

The product-manager reviews the completed roadmap. In most cases, this
happens autonomously (no user involvement). If the PM has concerns, the
coordinator revises and re-requests sign-off.

If the team can't converge after 3 revision cycles, it escalates to you.
Ralph stops. Start an interactive Claude session:

```bash
claude
```

The orchestrator will present the unresolved concerns. Discuss, decide,
and the coordinator will revise the roadmap based on your input.

### Step 4: Epic issues created

Once approved, the roadmap PR is merged and epic issues are created in
the docs repo at `pipeline:design`. Each epic references its source PRDs,
has dependency information, and carries an initiative label for grouping.

### What you get

- **Roadmap document** in `docs/planning/roadmap.md`
- **Epic issues** in the docs repo, each at `pipeline:design`
- **Initiative labels** on epic issues (e.g., `initiative:auth`)
- **Dependency ordering** — which epics block which

---

## Later phases (not yet built)

- **Design** — per-epic architecture, UX, task breakdown
- **Implement** — per-task coding
- **Verify** — code review, testing, security, spec compliance
- **Deliver** — E2E, docs, release

Each phase will be added to this guide as it's designed and tested.
