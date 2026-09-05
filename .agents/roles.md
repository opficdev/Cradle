# Cradle Agent Roles

## Purpose

Treat role assignment, approved Spec handoff, final review, and verification evidence as operational requirements for Cradle work. `AGENTS.md` takes precedence when rules conflict.

## Operating Rules

- Assign only one active writer to each file.
- Do not assign editing roles with overlapping file scope at the same time.
- Read-only roles must not edit files, stage, commit, push, resolve review threads, or change GitHub state without user approval.
- The primary agent owns integration, final diff inspection, and user reporting.
- Build-only verification is allowed. Do not run, install, boot, or launch an app or Simulator without current-turn user approval.
- Store AI workflow documents under `.agents/` and approved Specs under `.agents/specs/`.
- Non-trivial work follows `Design Brief → Designer Result → User Approval → Spec → Task Packet → Implementer → Code Reviewer → Verification Runner`.
- Update the Spec and obtain renewed user approval when requirements or scope change during implementation.
- `GitHub/CI Analyst` collects only facts from issues, pull requests, review threads, and Actions. `Designer` determines technical validity, priority, scope inclusion, and whether code changes are required.

## Model Assignment

| Tier | Use | Model |
| --- | --- | --- |
| `Primary` | Planning, implementation, public API decisions, final integration, and failed-check triage | Active primary agent |
| `SDD Gate` | Design analysis and final diff review | `gpt-6-astra`, `xhigh` |
| `Lightweight` | Read-only review, checklist verification, CI log summaries, documentation drafts, and architecture preflight | `gpt-5.3-codex-spark`; use `gpt-5.6-luna`, `high` only when unavailable |

| Role | Owner or custom agent | Tier |
| --- | --- | --- |
| Planner | Active primary agent | `Primary` |
| Designer | `designer` | `SDD Gate` |
| Implementer | Active primary agent | `Primary` |
| Architecture Watcher | `architecture_watcher` | `Lightweight` |
| Code Reviewer | `code_reviewer` | `SDD Gate` |
| Verification Runner | `verification_runner` | `Lightweight` |
| GitHub/CI Analyst | `github_ci_analyst` | `Lightweight` |
| Documentation Writer | `documentation_writer` | `Lightweight` |

## Dispatch and Fallback Rules

- `Designer` and `Code Reviewer` use only `gpt-6-astra`, `xhigh`, with no Luna fallback.
- Lightweight roles use Spark first and may use only the matching `*_luna` setting when Spark is unavailable.
- A `*_luna` role must not replace `Designer`, `Code Reviewer`, `Planner`, or `Implementer`.
- A side task `task_name` must exactly match the `.codex/agents/<name>.toml` filename without its extension.
- Send follow-up work for an existing role through `followup_task`.
- Escalate `Block`, `Needs Owner Decision`, `Fail`, unclear causes, boundary uncertainty, and missing required verification to `Primary`.

## Task Packet

```md
## Task Packet

- Source:
- Approved Spec:
- Goal:
- Scope:
- Out of scope:
- Acceptance criteria:
- Expected changed files:
- Current owner:
- Architecture risk: none / possible / confirmed
- Required roles:
- Model assignment:
- Execution authority: app or Simulator / external writes / CI or PR actions
- Verification:
- Stop conditions:
```

## Role Result Formats

### Designer

```md
## Designer Result

- Design Brief:
- Constraints:
- Alternatives:
- Changed boundaries:
- Acceptance criteria:
- Verification:
- Minimum commit units:
- Spec path:
- User approval needed:
```

### Architecture Watcher

```md
## Architecture Watch Result

- Verdict: Pass / Block / Needs Owner Decision
- Public API impact:
- Macro and diagnostic impact:
- Runtime ownership impact:
- Swift Concurrency impact:
- Package target impact:
- Dependency direction:
- Findings:
- Required user decision:
```

### Code Reviewer

```md
## Code Review Result

- Findings:
- Acceptance criteria coverage:
- Scope drift:
- Verification gaps:
- Verdict: Pass / Needs Owner Decision / Fail
```

### Verification Runner

```md
## Verification Result

- Commands:
- Exit status:
- Acceptance-criterion evidence:
- Unrun checks:
- Verdict: Pass / Fail
```

### GitHub/CI Analyst

```md
## GitHub CI Result

- Source checked:
- Observed facts:
- CI state:
- Missing evidence:
```

### Documentation Writer

```md
## Documentation Result

- Target:
- Source checked:
- Draft or changed files:
- Verification:
```
