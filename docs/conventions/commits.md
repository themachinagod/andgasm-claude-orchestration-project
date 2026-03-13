# Commit Conventions

All repositories in this project follow these commit conventions.

## Commit Message Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types

| Type | When to Use |
|------|------------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Code restructuring without behavior change |
| `test` | Adding or updating tests |
| `docs` | Documentation changes |
| `style` | Formatting, whitespace |
| `perf` | Performance improvement |
| `ci` | CI/CD pipeline changes |
| `chore` | Build process, tooling, dependencies |
| `status` | STATUS.md or active-work updates (orchestrator only) |

### Scope

Use the component or feature area, e.g., `auth`, `api`, `schema`.

### Subject

- Imperative mood: "add" not "added" or "adds"
- No period at the end
- Max 72 characters

### Footer

Reference GitHub Issues:
- `Resolves #123` — closes the issue
- `Refs #123` — references without closing
- `Epic: org/docs-repo#45` — links to docs repo epic

## Examples

```
feat(auth): add JWT token refresh endpoint

Implements automatic token refresh when access token expires within
5 minutes of a request. Refresh tokens are rotated on each use.

Resolves #15
Epic: account/project-docs#8
```

```
status: update after review session on #3

PRD review complete — 7 items identified, stakeholder input needed.
```
