# Cradle Agent Instructions

## Scope

- These instructions apply to the repository root.
- Read every document that matches the current task before acting.

## Required Routing

| Task | Required document |
| --- | --- |
| Every task | `.agents/rules/general.md` |
| Non-trivial design, planning, implementation, review, or verification | `.agents/roles.md` |
| Public API, Macro, generated code, compiler diagnostic, runtime ownership, Swift Concurrency, package target, dependency, or architecture documentation | `.agents/rules/architecture.md` |
| Approved Spec creation or review | `.agents/specs/README.md` |

## Routing Rules

- `AGENTS.md` is the repository rule entry point.
- Read `.agents/rules/general.md` and every document that matches the current task before editing, reviewing, or verifying.
- Non-trivial design or implementation work follows an approved `Designer` result and user-approved Spec.
- Independent read-only review and CI analysis may proceed without an approved Spec.
- Public API, Macro expansion, compiler diagnostics, runtime ownership, Swift Concurrency, and target dependency direction are explicit repository boundaries.
- Pull requests, issues, reviews, and Release documents must be written in Korean.

## Local Planning Artifacts

- Store Specs under `.agents/specs/` and Plans under `.agents/plans/`.
- Approved Specs and Plans are local artifacts and must not be tracked by Git.
- Track only `.agents/specs/README.md` as the format guide.
