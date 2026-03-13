---
description: Code quality standards for component repositories
globs: src/**/*,lib/**/*,app/**/*
---

# Code Quality Rules

- Write for readability first, optimization second
- Keep functions focused — single responsibility, ~40 lines max
- Keep files under ~300 lines; split when larger
- No dead code — delete it, git has history
- No commented-out code blocks
- Prefer explicit over implicit
- Use descriptive, intention-revealing names; avoid abbreviations
- Never swallow exceptions silently
- Use typed/structured errors
- Log errors with context sufficient for debugging
- Pin dependency versions; commit lockfiles
- No secrets in code or config
- Validate and sanitize all external inputs
- Use parameterized queries for all database operations
