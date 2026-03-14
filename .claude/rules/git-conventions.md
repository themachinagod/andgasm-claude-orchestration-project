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
- PRs to main require CI pass (enforced via GitHub branch protection)
- Squash merge to maintain clean history: `gh pr merge --squash --delete-branch`
- Delete branch after merge

### PR Review Enforcement

Review enforcement is **pipeline-process-based**, not GitHub-approval-based.
All agents run under the same GitHub account, so GitHub's "require N
approvers" mechanism cannot distinguish between the PR author and
reviewers. Instead:

- **GitHub branch protection** enforces CI status checks only (build,
  test, lint must pass). No required approvers setting.
- **Pipeline review cycle** enforces review rigour. Every PR goes
  through a structured review with specialist reviewers, PR comments,
  concern routing, and a coordinator gate. This is MORE rigorous than
  a simple GitHub approval — it includes domain-specific review,
  circuit breakers, and traceability.
- **No PR is merged without review.** The coordinator merges only
  after ALL required reviewers have posted their assessment via PR
  comments and all concerns are resolved. This is non-negotiable
  regardless of GitHub approval settings.
- **The coordinator is the merge authority.** Only the coordinator
  (or orchestrator for review phase) runs `gh pr merge`. Engineers,
  reviewers, and specialists never merge — they review and comment.

### What "approved" means in this pipeline

When agents write "approved" in PR comments, this is a **process
approval** — a structured assessment that the PR meets the reviewer's
domain standards. It is NOT a GitHub formal review approval. The
coordinator reads these comments to determine consensus before merging.

A PR is ready to merge when:
1. CI is green (`gh pr checks` passes)
2. All required reviewers have posted positive assessments
3. All PR comment concerns are resolved
4. The coordinator (merge authority) confirms the above

## PR Lifecycle (Review Phase)

During PRD review, a single PR stays open through the full review cycle:

1. `/submit-prds` creates the PR with all PRD + discovery files
2. Review team analyses and leaves PR comments
3. Stakeholder facilitator resolves comments with user input
4. Review team re-reviews
5. On all reviewer concerns resolved: coordinator merges PR, advances issue

## Merge Authority

The following agents are the **process authority** for merge decisions
in their domain. They determine when review is complete and execute
the merge. They are not necessarily different GitHub users — authority
is role-based, not account-based.

| Agent | Merge Authority For |
|-------|---------------------|
| orchestrator | PRD PRs (on review team approval) |
| project-coordinator | Roadmap PRs, design PRs, implementation PRs |
| spec-compliance | Final gate on implementation PRs (approval required before coordinator merges) |
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
