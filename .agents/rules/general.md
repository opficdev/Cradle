# Cradle General Agent Rules

## Logic Preservation and Optimization

- Preserve existing program logic by default.
- Change logic only when results remain identical and time or space complexity strictly improves, or when the user explicitly requests the change.
- Retain the existing logic when there is no clear complexity improvement.

## Swift Style

- Do not add explicit type annotations unless required.
- Set `opfic` as the author in new Swift file headers.
- Prefer `<` and `<=` over `>` and `>=` when the condition remains clear.
- Review consumer-facing documentation and public behavior tests with every public API change.
- Treat `Sendable`, actor isolation, cancellation, and error mapping as explicit review points for concurrency changes.

## Development Comments

- Use `//` for development comments. Do not use `///` for development comments.
- Write development comments in Korean noun phrases, matching the prose form used in internal commit messages.
- Add a concise comment to each implementation type, variable, and method that explains its intended use and core logic.
- Keep implementation names in comments in their original form.

## Documentation and Response

- Store AI workflow and rule documents under `.agents/`.
- Store approved workflow Specs under `.agents/specs/`.
- Do not store tracked AI workflow documents under `docs/`.
- For code modifications, return only precise changed locations and changed code unless the user requests an explanation.
- Pull request and review documents must be written in Korean.

## Repository-Local Rules

- Keep Cradle working rules in this repository.
- `AGENTS.md` and routed `.agents/` documents are the canonical repository rules.
- Repository-local rules override global memory.
