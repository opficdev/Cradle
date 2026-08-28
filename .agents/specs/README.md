# Cradle Spec Format

After the user approves a `Designer Result`, the Planner creates a Spec in this directory for every non-trivial design or implementation task. Use `<issue-number>-<short-topic>.md` for issue-based work and `user-<YYYYMMDD>-<short-topic>.md` for user requests without an issue.

## Responsibility

- A `Design Brief` gives the Planner request details, current state, scope, out-of-scope items, and known constraints for the Designer.
- A `Designer Result` analyzes constraints, alternatives, changed boundaries, acceptance criteria, verification, and minimum commit units for user approval.
- A Spec persists a user-approved `Designer Result` as the shared implementation, review, and verification contract.
- A `Task Packet` references the approved Spec path and acceptance criteria, and records role assignment and execution authority for the current task.

## Required Format

```md
# <Spec title>

- Source:
- Approved Designer Result:
- User approval:

## Constraints

-

## Alternatives and decision

-

## Changed boundaries

-

## Acceptance criteria

- [ ]

## Verification

- Command:
- Evidence:

## Minimum commit units

1.

## Execution constraints

- app or Simulator execution:
- External writes:
- CI or PR actions:
```

## Change Control

- When requirements or scope change during implementation, update the Spec and obtain renewed user approval before updating the `Task Packet` or implementation.
- A Spec records behavior, acceptance criteria, and prohibited execution. A `Task Packet` separately records role-specific current-task authority and exact verification commands.
