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
| Workflow, Git, commit, CI, Release, documentation, or verification | `.agents/rules/project-workflows.md` |

## Routing Rules

- `AGENTS.md` is the repository rule entry point.
- Read `.agents/rules/general.md` and every document that matches the current task before editing, reviewing, or verifying.
- Non-trivial design or implementation work follows an approved `Designer` result and user-approved Spec.
- Independent read-only review and CI analysis may proceed without an approved Spec.
- Public API, Macro expansion, compiler diagnostics, runtime ownership, Swift Concurrency, and target dependency direction are explicit repository boundaries.
- Pull requests, issues, reviews, and Release documents must be written in Korean.

## Pull Request Review Guidance

- Write review summaries, findings, and inline comments in Korean.
- Before reviewing a pull request, identify and fully analyze its linked issue, then verify the diff against the issue scope, out-of-scope items, and acceptance criteria before reporting findings.
- Treat the linked issue as the primary review contract. If no linked issue exists or its scope is ambiguous, report that limitation before making a scope-compliance claim.
- Separate issue-compliance findings from technical findings. For each finding, cite the relevant issue criterion and the exact file or line evidence.
- Prioritize correctness, regressions, public API stability, Macro and Swift Concurrency safety, scope drift, and missing tests over style preferences.

## Local Planning Artifacts

- Store Specs under `.agents/specs/` and Plans under `.agents/plans/`.
- Approved Specs and Plans are local artifacts and must not be tracked by Git.
- Track only `.agents/specs/README.md` as the format guide.
