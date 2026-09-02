# Cradle Project Workflow Rules

## Canonical Source

- Treat `AGENTS.md` and routed `.agents/` documents as the canonical Cradle working rules.
- Use global memory only as historical context and follow repository rules when they conflict.
- Update repository-local rules before changing repository architecture policy.

## Current Checkout and Execution Authority

- Work in the current checkout by default.
- Do not create a `git worktree` unless the user explicitly requests it in the current turn.
- An approved Spec records constraints, acceptance criteria, and prohibited actions. A `Task Packet` records role assignment and current-turn execution authority.
- Do not infer app or Simulator execution, GitHub writes, CI actions, pull request actions, or Release actions from a Spec or Task Packet that does not grant that authority.
- Do not run, install, boot, or launch an app or Simulator without current-turn user approval.

## Verification

| Change | Required checks |
| --- | --- |
| Swift source or test | `swift build`, `swift test`, and changed-file SwiftLint when available |
| Public API or documentation | Applicable public behavior tests and consumer-documentation review |
| Package manifest | `swift build`, `swift test`, and package dependency diff review |
| AI workflow documents or agent TOML | Baseline diff, staged diff, untracked Markdown or TOML format checks, and role-model-fallback checks |
| CI or Release workflow | YAML review and affected workflow check when available |

- Record each verification command, exit status, acceptance-criterion evidence, and unrun check in the Verification Result.
- Treat a missing SwiftLint binary as an unrun check, not lint success.
- App, Simulator, launch, installation, boot, and build-and-run commands require current-turn user approval.

### AI Workflow Document Checks

```sh
git diff --check -- AGENTS.md .agents .codex/agents
git diff --cached --check -- AGENTS.md .agents .codex/agents
git ls-files --others --exclude-standard -- AGENTS.md .agents .codex/agents |
	rg '\.(md|toml)$' |
	while IFS= read -r file; do
		output=$(git diff --no-index --check --no-color /dev/null "$file" || true)
		test -z "$output" || {
			printf '%s\n' "$output" >&2
			exit 1
		}
	done
```

- A `git diff --no-index --check` exit status of `1` alone indicates a file difference, not a formatting failure.

## Git and GitHub Delivery

- Keep each commit as the smallest independently reviewable change.
- Treat unrelated working-tree changes as user-owned.
- Commit, push, pull request creation, review reply, review-thread change, Release, and tag creation require explicit user authority.
- Treat live issues, pull requests, review threads, CI runs, and Release state as GitHub sources of truth.
- `GitHub/CI Analyst` records live facts only. Designer or Primary determines technical validity, priority, scope inclusion, and whether a change is required.

## Commit Guidance

- Start commit messages with a prefix used by recent local commits, such as `feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `ui`, or `rollback`.
- After `prefix:`, end the Korean title with a nominalization of the changed action, such as `생성`, `추가`, `차단`, `검증`, or `문서화`. Do not end a title with a static category such as `규칙` or `안내` when it does not describe the change itself.
- Write commit-message prose in Korean and do not add a commit-message body.
- Keep implementation names, file paths, commands, branch names, and commit hashes unchanged.
- Inspect the actual diff and recent non-merge `git log` before proposing a commit message.
- Split broad work by independently reviewable responsibility when the user requests staged commits.

## Documentation

- Write pull request, issue, review, and Release documents in Korean.
- Use `.github/pull_request_template.md` for pull request bodies when it exists.
- If the user requests only document text, return text without creating files or GitHub content.
- Report unrun build, test, app, and Simulator checks for documentation-only changes.
- Keep tracked AI workflow documents under `.agents/` and `.codex/agents/`.

## CI and Release

- CI performs validation and must not create a Release or tag.
- Release creation requires successful required verification, explicit user authority, and the designated Release workflow.
- Do not move or overwrite a published tag.
