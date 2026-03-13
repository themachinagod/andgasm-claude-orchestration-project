---
name: orient
description: >
  Read all workspace state and produce a situational report. Use this at
  the start of any session to understand where the project is, what's
  been done, what's in flight, and what needs attention.
---

## Instructions

Gather state from all sources and produce a clear report.

### 1. Read Local State

- Read `[DOCS_REPO]/STATUS.md`
- Read `[DOCS_REPO]/repos.yaml`
- List files in `[DOCS_REPO]/active-work/` and read any that exist
  (excluding templates/)
- Read `CLAUDE.md` for workspace context
- Run `git log --oneline -10` in the docs repo for recent activity
- Run `git status` for uncommitted changes
- Run `git branch` to see current branch

### 2. Read GitHub State

```bash
cd [DOCS_REPO]
gh issue list --state open --json number,title,labels,assignees
```

For each component repo in repos.yaml (if any exist):
```bash
cd [component-repo]
gh issue list --state open --json number,title,labels
gh pr list --json number,title,state
cd ..
```

### 3. Check Review State

If any issues have `pipeline:review` label, check the review sub-state:

```bash
cd [DOCS_REPO]
gh issue list --state open --label "pipeline:review" --json number,title
```

For each review issue:
```bash
gh issue view [NUMBER] --json comments --jq '.comments | length'
gh issue view [NUMBER] --json labels --jq '.labels[].name'
```

Determine sub-state:
- No review comments yet → "Awaiting first review"
- Has "needs-stakeholder-input" label → "Waiting for stakeholder input"
- Latest comment says "input provided" → "Awaiting re-review"
- Latest comment says "approved" → "Approved, ready to merge"

```bash
cd ..
```

### 4. Check Local Repos

For each component repo path in repos.yaml, check if the directory exists.
If it does, run `git status` to check for uncommitted work.

### 5. Produce Report

Output a structured report with these sections:

**Project State Summary**
- One-paragraph overview of where the project stands

**Pipeline Overview**
- Count of issues at each pipeline stage across all repos

**Review State** (if applicable)
- Current review sub-state for any `pipeline:review` issues
- PR number, review cycle count, items pending

**Active Epics**
- List each in-progress epic with current status and blockers

**Open Issues**
- Issues by pipeline stage

**Open PRs**
- PRs with review status

**Blockers**
- Anything that's stuck and why

**Recommended Next Actions**
- Prioritized list of what should be done next, with rationale

**Recent Activity**
- What happened in the last few commits/sessions
