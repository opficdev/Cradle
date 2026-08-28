# Cradle Role Workflows

## Purpose

Use this file after reading `AGENTS.md` and `.agents/roles.md`. `.agents/roles.md` defines role authority; this file defines role sequences for common Cradle tasks. Follow `AGENTS.md` when rules conflict.

## Primary Agent Protocol

1. Read `AGENTS.md`, `.agents/rules/general.md`, `.agents/roles.md`, and this file.
2. Select the workflow that matches the request.
3. Classify the work as simple or non-trivial.
4. For non-trivial work, create a `Design Brief`, obtain a `Designer Result`, obtain user approval, persist the approved Spec, and create a `Task Packet` from that Spec.
5. For simple work, create a `Task Packet` directly from the request with scope and execution authority.
6. Assign only roles required by the selected workflow and use the model tier defined in `.agents/roles.md`.
7. Dispatch a configured custom agent only with the exact `.codex/agents/<name>.toml` filename without its extension.
8. Keep `Primary` work with the active primary agent and send delegated results back to Primary for integration.
9. Do not substitute Primary for a required `SDD Gate` or `Lightweight` custom agent.
10. Stop for a user decision when a required role returns `Block` or `Needs Owner Decision`.
11. Return a `Fail` result from Code Reviewer or Verification Runner to Primary for cause classification, scoped correction, repeated review, and repeated verification.
12. Run the completion checks defined in `.agents/rules/project-workflows.md` and report changed files, Spec path, acceptance-criterion evidence, delegated roles, and unresolved decisions.

## Universal Stop Conditions

Stop and ask the user before editing when the Task Packet conflicts with `AGENTS.md`, a non-trivial task lacks an approved Spec, a required role cannot be dispatched through its configured name, two editing roles would overlap, or verification requires a policy decision.

When requirements or scope change after a Task Packet exists, stop editing. Renew the Spec, obtain renewed user approval, update the Task Packet, and only then resume implementation.

Do not run, install, boot, or launch an app or Simulator without current-turn user approval. Do not create a `git worktree` unless the user explicitly requests it in the current turn.

## Review and Verification Return Path

1. When Code Reviewer or Verification Runner returns `Fail`, Primary classifies the cause as an implementation defect, missing verification, scope change, or policy decision.
2. For an implementation defect or missing verification within the approved Task Packet, Implementer corrects the assigned scope.
3. For a scope change or policy decision, stop editing and follow Spec renewal, renewed user approval, and Task Packet update before continuing.
4. After any correction, Code Reviewer reviews the resulting diff again and Verification Runner repeats the affected checks.
5. Do not report completion until Code Reviewer and Verification Runner return results that satisfy the Task Packet.

## Workflow Selection

| Request | Workflow |
| --- | --- |
| Issue implementation, feature, or bug fix | Issue-Driven Implementation |
| Public API, Macro, generated code, runtime, Swift Concurrency, target, dependency, or architecture documentation | Architecture-Sensitive Implementation |
| Pull request review feedback or review thread | Review Feedback Follow-Up |
| GitHub Actions, CI, or workflow failure | CI Failure Triage |
| Pull request body, issue text, Release note, README wording, or review reply draft | Documentation-Only Writing |
| `AGENTS.md`, `.agents/`, `.codex/agents/`, or AI role routing | AI Workflow Maintenance |

## Issue-Driven Implementation

1. `GitHub/CI Analyst` collects live issue or pull request facts when current GitHub state matters.
2. Planner creates a `Design Brief`.
3. Designer returns a `Designer Result`; the user approves it.
4. Planner persists the approved Spec and creates a `Task Packet`.
5. Run `Architecture Watcher` before editing when the Task Packet identifies architecture risk.
6. Implementer changes only the assigned scope.
7. Code Reviewer checks acceptance criteria and scope drift.
8. Verification Runner records acceptance-criterion evidence and runs allowed checks.

## Architecture-Sensitive Implementation

1. Planner creates a `Design Brief`.
2. Designer returns a `Designer Result`; the user approves it.
3. Planner persists the approved Spec and creates a `Task Packet`.
4. Architecture Watcher returns `Pass` before Implementer edits.
5. Implementer changes only the approved boundary.
6. Run Architecture Watcher again when ownership, imports, target dependencies, or runtime behavior changed.
7. Code Reviewer checks boundary compliance and scope drift.
8. Verification Runner records evidence for every acceptance criterion.

## Review Feedback Follow-Up

1. `GitHub/CI Analyst` collects live review-thread and CI facts only.
2. Planner creates a `Design Brief`.
3. Designer classifies each request as `required`, `optional`, `already handled`, or `rejected` using code, diff, approved Spec, and architecture evidence.
4. The user approves the resulting scope; Planner persists the Spec and creates a `Task Packet`.
5. Implementer changes only accepted requests.
6. Code Reviewer checks the final diff.
7. Verification Runner records verification evidence.
8. `GitHub/CI Analyst` rechecks live state before a user-authorized reply or review-thread change.

## CI Failure Triage

1. `GitHub/CI Analyst` inspects the failing run, job, and log excerpts.
2. Planner separates workflow, environment, dependency, and source failure categories in a `Design Brief`.
3. Designer returns a `Designer Result`; the user approves it.
4. Planner persists the Spec and creates a `Task Packet`.
5. Verification Runner reproduces only allowed local checks.
6. Implementer changes the confirmed root cause.
7. Code Reviewer reviews the diff.
8. Verification Runner records the final evidence.

## Documentation-Only Writing

1. Planner and Designer handle non-trivial scope.
2. The user approves the result; Planner persists the Spec and creates a `Task Packet` when required.
3. Documentation Writer inspects the actual diff before drafting documents that depend on implementation state.
4. Code Reviewer verifies wording that claims changed behavior.
5. `GitHub/CI Analyst` checks live GitHub state when needed.
6. Verification Runner runs Markdown and file checks for changed files.

Return text directly without creating files when the user requests text only.

## AI Workflow Maintenance

1. Planner creates a `Design Brief`.
2. Designer returns a `Designer Result`; the user approves it.
3. Planner persists the approved Spec and creates a `Task Packet`.
4. Implementer changes only the designated AI workflow files.
5. Run Architecture Watcher only when architecture policy or architecture rules change.
6. Code Reviewer checks role routing, authority, model, fallback, and scope consistency.
7. Verification Runner runs the assigned document checks.

## Completion Record

```md
## Workflow Result

- Workflow:
- Approved Spec:
- Changed files:
- Architecture decision:
- Verification:
- Delegated roles:
- Remaining decisions:
```
