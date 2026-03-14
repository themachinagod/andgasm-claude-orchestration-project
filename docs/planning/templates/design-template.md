# Design: [Epic Title]

> Architecture and design for EPIC-NNN. Produced by the design team
> (project-coordinator + architect + specialists) during `pipeline:design`.
>
> **Epic issue:** #[NNN]
> **Source PRDs:** [list PRDs this epic traces to]
> **Repos involved:** [list component repos from repos.yaml]
> **Design team:** [list agents who contributed]
> **Generated:** [YYYY-MM-DDTHH:MM:SSZ]

---

## Context and Scope

### Overview

[What this epic delivers and why — 2-3 paragraphs maximum.]

### Linked PRDs

| PRD | Relevant Sections | Summary |
|-----|-------------------|---------|
| PRD-NNN | Sections X.Y | [What this PRD contributes to this epic] |

### Repos Involved

| Repo | Stack | Role in This Epic |
|------|-------|-------------------|
| [repo-name] | [from repos.yaml] | [What changes in this repo] |

### Level 0 Constraints

[Which foundational designs (data model, auth model, API conventions,
UX model) apply to this epic and how they constrain the design.]

---

## Requirements Traceability

Map every PRD requirement to a design element. No orphaned requirements.
No design elements without a PRD justification.

| PRD | Requirement | Section | Design Element | Notes |
|-----|-------------|---------|----------------|-------|
| PRD-NNN | Section X.Y: [requirement text] | [ref] | [component/API/schema that addresses it] | |

---

## System Design

### Architecture Overview

[Component diagram, data flow, and how this fits into the existing
system. Reference Level 0 designs (data model, API conventions) and
show how this epic integrates with them.]

### Component Design

[For each new or modified component: purpose, interfaces, dependencies,
data it owns, and how it communicates with other components.]

### Data Flow

[How data moves through the system for this epic's key operations.
Mermaid sequence or flowchart diagrams recommended.]

---

## API Contracts

> Remove this section if the epic has no API surface.

### Endpoints

| Method | Path | Description | Request | Response |
|--------|------|-------------|---------|----------|
| | | | | |

### Contract Details

[OpenAPI references, request/response schemas, error handling,
versioning approach. Reference API conventions from Level 0 design.]

---

## Data Design

> Remove this section if the epic has no data concerns.

### Schema Changes

[New tables/collections, column additions, relationship changes.
Reference the Level 0 data model for entity ownership and boundaries.]

### Migration Strategy

[How to apply schema changes safely — zero-downtime migration steps,
data backfill approach, rollback plan.]

### Query Patterns

[Key query patterns and their expected performance characteristics.
Index strategy for new access patterns.]

---

## UX Design

> Remove this section if the epic has no UX concerns.

### User Flows

[Complete flows for each user story: entry point → happy path → completion.
Include error states, empty states, loading states, and edge cases.]

### Component Specifications

[New or modified UI components: variants, states, content constraints,
responsive behavior, accessibility requirements.]

### Accessibility Requirements

[WCAG compliance requirements specific to this epic. Keyboard navigation,
screen reader behavior, focus management, color contrast.]

---

## Frontend Architecture

> Remove this section if the epic has no frontend concerns.

### Component Architecture

[Smart/dumb component hierarchy, shared components (new vs reuse),
composition patterns.]

### State Management

[State management approach for this epic's features. Which pattern
and why. Reference Level 0 conventions if established.]

### Performance Targets

[Bundle budget impact, Core Web Vitals targets, lazy loading strategy,
SSR/SSG considerations.]

---

## Cross-Epic Integration

### Integration with Existing Designs

[How this design connects to other merged designs. List specific
integration points — shared APIs, events, data models.]

### Shared Concerns

[How this design handles cross-cutting concerns consistently with
the platform: logging, error handling, auth, config, monitoring.]

### Compatibility Notes

[Compatibility with existing codebase patterns. Any deviations from
established patterns require an ADR.]

---

## Quality Gates

### Code Quality Gates (enforced in CI/CD)

| Gate | Target | Tooling |
|------|--------|---------|
| Unit test coverage | ≥ [N]% | [framework] |
| Integration test coverage | ≥ [N]% | [framework] |
| Linting | Zero errors | [linter] |
| Static analysis | Zero errors | [tool] |
| API contract validation | Schema conformance | [tool] |
| Build | Zero warnings | [tool] |

### Non-Functional Gates (validated during implementation review)

| Gate | Target | How Measured |
|------|--------|-------------|
| Response time (P95) | ≤ [N]ms | [tool/method] |
| Throughput | ≥ [N] req/s | [tool/method] |
| Accessibility | WCAG [level] | [auditing tool] |
| Security | [requirements] | [OWASP checks / tool] |
| Browser/platform support | [targets] | [matrix] |

### Design-Level Gates (enforced during design PR review)

- [ ] Requirements traceability complete (spec-compliance validates)
- [ ] Cross-epic consistency verified (architect validates)
- [ ] Codebase compatibility confirmed (specialists validate)
- [ ] No unresolved open questions

---

## Open Questions / ADRs

### Open Questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| 1 | | | Open / Resolved |

### ADRs

| ADR | Title | Status |
|-----|-------|--------|
| ADR-NNN | [title] | Proposed / Accepted |

[ADR files live in `docs/architecture/decisions/`. Link to them here.]

---

## Design Notes

Any context, rationale, or trade-offs from the design process that
future sessions should know about.

- [Note 1]
