---
description: Testing standards for component repositories
globs: "**/*test*,**/*spec*,tests/**/*"
---

# Testing Rules

- Name tests: `[MethodUnderTest]_[Scenario]_[ExpectedResult]`
- Follow Arrange-Act-Assert or Given-When-Then structure
- Each test verifies ONE behavior
- Tests are independent — no shared mutable state, no ordering dependency
- Tests are deterministic — no flaky tests allowed
- Use factories/builders for test data, not fixtures
- Each test sets up and tears down its own state
- Coverage targets: line >= 80%, branch >= 70%, new code >= 90%
- Test happy path, edge cases, boundary conditions, error paths, input validation
- Do NOT test framework internals, private methods directly, or trivial getters
