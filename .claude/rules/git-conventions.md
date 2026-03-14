---
description: Git workflow — all agents follow the same discipline across all repos
globs: "**/*"
---

# Git Conventions

## Before Starting Any Work

ALWAYS pull latest main before creating a branch:
```bash
cd [target-repo]
git checkout main && git pull origin main
git checkout -b <type>/<reference>-<short-description>
```

## Branch Types

### Docs Repo Branches

| Type | When | Example |
|------|------|---------|
| `docs/` | PRDs, architecture, UX specs, ADRs, epic decomposition | `docs/PRD-001-user-auth` |
| `chore/` | Project setup, config, label sync | `chore/initial-setup` |
| `release/` | Release preparation | `release/v1.0.0` |

### Component Repo Branches

Format: `<type>/<issue-number>-<short-description>`

| Type | When | Example |
|------|------|---------|
| `feat/` | New features | `feat/15-user-auth-api` |
| `fix/` | Bug fixes | `fix/23-token-expiry` |
| `refactor/` | Code restructuring | `refactor/12-extract-service` |
| `test/` | Test additions | `test/18-auth-coverage` |
| `chore/` | Build, CI, config | `chore/setup-ci` |

- Branch from `main` (never from another feature branch unless coordinating)
- Keep branches short-lived (days, not weeks)
- Delete after merge

## What Goes Through Branch + PR

All content changes in the docs repo:
- PRDs (`[DOCS_REPO]/docs/prd/`)
- Architecture docs and ADRs (`[DOCS_REPO]/docs/architecture/`)
- UX design specs (`[DOCS_REPO]/docs/design/ux/`)
- Implementation designs (`[DOCS_REPO]/docs/design/implementation/`)
- Epic decomposition files (`[DOCS_REPO]/active-work/`)
- Convention changes (`[DOCS_REPO]/docs/conventions/`)

All code changes in component repos.

## What Goes Direct to Main

Operational state updates only:
- `[DOCS_REPO]/STATUS.md` updates
- Session log entries appended to `[DOCS_REPO]/active-work/` files

## Commits

Format: `<type>(<scope>): <subject>`
Types: feat, fix, refactor, test, docs, style, perf, ci, chore, status
Footer: `Resolves #123` or `Refs #123` or `Epic: org/docs-repo#45`

- Imperative mood: "add" not "added"
- Max 72 characters for subject line
- Each commit should build and pass tests

## Before Creating a PR

Rebase onto latest main and verify:
```bash
cd [target-repo]
git fetch origin
git rebase origin/main
git push --force-with-lease
```

## PRs

- Every PR must reference a GitHub Issue where applicable
- PRs to main require CI pass and review approval
- Squash merge to maintain clean history: `gh pr merge --squash --delete-branch`
- Delete branch after merge

## PR Lifecycle (Review Phase)

During PRD review, a single PR stays open through the full review cycle:

1. `/submit-prds` creates the PR with all PRD + discovery files
2. Review team analyses and leaves PR comments
3. Stakeholder facilitator resolves comments with user input
4. Review team re-reviews
5. On approval: merge PR, advance issue to `pipeline:decompose`

## Merge Responsibilities

| Agent | Merges |
|-------|--------|
| product-manager | PRD PRs (on review team approval) |
| architect | Architecture doc PRs |
| frontend-architect | Frontend architecture PRs |
| project-coordinator | Epic decomposition PRs, epic design PRs |
| spec-compliance | Component repo implementation PRs (final gate) |
| release-manager | Release PRs |

## Escalation to Docs Repo

When implementation reveals gaps in upstream documents, create a blocking
amendment issue in the docs repo:

```bash
cd [DOCS_REPO]
gh issue create --title "Amendment: [doc] missing [what]" \
  --label "type:amendment,pipeline:[upstream-stage],blocked" \
  --body "Blocks [component-repo]#[task-issue]. [specific gap]."
cd ..
```

Add `blocked` label to the component task issue.
