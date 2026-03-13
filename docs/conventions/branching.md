# Branching Strategy

All repositories in this project follow these branching conventions.

## Primary Branch

`main` is the primary branch. It is always deployable. All work happens
on feature branches that merge to `main` via PR.

## Branch Naming

```
<type>/<issue-number>-<short-description>
```

### Types

| Prefix | When to Use |
|--------|------------|
| `feat/` | New feature implementation |
| `fix/` | Bug fix |
| `refactor/` | Code restructuring |
| `docs/` | Documentation changes |
| `test/` | Test additions or changes |
| `chore/` | Tooling, dependencies, CI |
| `hotfix/` | Critical production fix |

### Examples

```
feat/15-user-auth-api
fix/23-token-expiry-handling
docs/3-prd-submission
```

## Starting Work

Before creating a feature branch, always start from an up-to-date main:

```bash
git checkout main
git pull origin main
git checkout -b feat/[issue-number]-[short-description]
```

## During Development

### Keeping Your Branch Current

If main has moved, rebase before creating a PR:

```bash
git fetch origin
git rebase origin/main
```

### Commit Discipline

- Commit frequently — small, logical commits
- Each commit should build and pass tests
- Follow commit conventions from `commits.md`
- Reference the GitHub Issue in commit footers

## Creating a PR

```bash
git fetch origin
git rebase origin/main
# Verify build + tests pass
git push origin feat/[branch-name] --force-with-lease
```

Use `--force-with-lease` instead of `--force` to prevent overwriting
changes someone else pushed.

### PR Requirements

- Every PR must reference a GitHub Issue (`Resolves #NNN`)
- PRs to main require CI pass
- PR description must follow the PR template

## Merge Strategy

**Squash merge** to main. One commit per feature/fix.

```bash
gh pr merge [number] --squash --delete-branch
```

## Cross-Repo Coordination

When a feature spans multiple repositories:

1. Reference the docs repo epic in all related PRs
2. Merge shared-lib changes FIRST (respect `repos.yaml` dependency order)
3. Verify downstream repos build after upstream merges
