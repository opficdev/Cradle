# Cradle Architecture Rules

## Purpose

Cradle is a Swift Package for dependency injection. Public API stability, Macro expansion and compiler diagnostics, generated code, runtime ownership, Swift Concurrency safety, and package target dependency direction are architecture decision boundaries.

## Ownership Boundaries

| Area | Owner | Responsibility |
| --- | --- | --- |
| `Package.swift` | package manifest | Platform floor, product, target, test target, and package dependency declarations |
| `Sources/Cradle` | library | Consumer-facing public API and internal runtime implementation |
| `Tests/CradleTests` | test suite | Public behavior and library boundary verification |
| `CradleMacros` | Future Macro target | Macro declarations, expansion, and compiler diagnostics |
| `CradleTesting` | Future test-support target | Macro and runtime test support with fixtures |

## Public API Rules

- Adding or removing a `public` declaration, or changing a signature, default value, or protocol requirement is a public API change.
- Add or update consumer-facing documentation and tests for every public API change.
- Do not change the API or default behavior of the consumer-imported `Cradle` product without explicit user approval.
- Keep runtime types internal unless a stable consumer extension point is necessary.

## Macro and Generated Code Rules

- Macro targets, Macro declarations, expansion output, and compiler diagnostic wording and locations are architecture-sensitive changes.
- Generated code must not rely on declaration order, implicit global state, or undocumented compiler behavior.
- Design compile-fail fixtures and Macro-specific tests with the task that introduces the corresponding target.
- Do not add `CradleMacros`, `CradleTesting`, or compiler plugin dependencies before Macro work is introduced.

## Runtime Ownership and Concurrency Rules

- Make dependency registration, resolution, scope, lifecycle, cache, and mutable shared-state ownership explicit.
- Protect shared mutable state with actor isolation or an equivalent concurrency boundary.
- Require focused review and tests for `Sendable` conformance, actor isolation, task cancellation, and concurrent resolution behavior.
- Treat ownership, initialization order, and failure propagation between generated code and runtime code as consumer-observable behavior.

## Package Boundary Rules

- Changes to `Package.swift` dependencies, products, platforms, or targets are architecture-sensitive.
- Require `Architecture Watcher` review before implementing a new target, target dependency, or Macro implementation dependency.
- Do not add an application target, app lifecycle, Simulator, or external service dependency without explicit user approval.
- Keep development-only tooling out of the distributable `Cradle` product dependency graph.

## Architecture Watcher Gate

Require `Architecture Watcher` review before implementation for changes to public API, concurrency boundaries, package manifests, target dependency direction, Macro expansion, compiler diagnostics, runtime ownership, or architecture documentation.

- `Pass`: Continue implementation.
- `Block`: Stop implementation.
- `Needs Owner Decision`: Continue only after a user decision.
