# Contributing to Lumoshell

Thanks for your interest in contributing.

## Development Setup

Prerequisites:

- macOS
- Bash
- Swift toolchain
- Homebrew (optional, for formula testing)

Clone and verify:

```sh
bash scripts/verify.sh
```

## Making Changes

- Keep changes focused and minimal.
- Preserve CLI behavior unless the change explicitly updates the contract.
- For installer/launchd/shell-hook changes, include rationale in the PR description.
- Prefer idempotent and safe-by-default behavior.

## Testing Expectations

Run before opening a PR:

```sh
bash scripts/verify.sh
```

`scripts/verify.sh` includes `tests/install_uninstall_test.sh`, which is required for this project because installer/uninstaller changes modify user startup files and must remain idempotent and safe.

If you touched Homebrew formula behavior, also run:

```sh
./scripts/test-homebrew-local.sh --cleanup
```

## Pull Request Guidelines

- Describe the user impact first, then implementation details.
- Include manual verification steps and expected outcomes.
- Link relevant issues, if any.
- Keep unrelated refactors out of the same PR.

## Commit Message Style

- Use concise, imperative titles (for example: `Improve LaunchAgent fallback handling`).
- Prefer messages that explain why the change is needed.

