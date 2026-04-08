# Lumoshell

`lumoshell` keeps Apple Terminal profiles aligned with macOS appearance.

`lumoshell` was originally developed as a personal utility and is now published as an open-source project.

- Light mode profile default: `Basic`
- Dark mode profile default: `Pro`
- Optional overrides: `MAC_TERMINAL_LIGHT_PROFILE`, `MAC_TERMINAL_DARK_PROFILE`

## Requirements

- macOS (Apple Terminal)
- `bash`
- Swift toolchain (for local builds from source)
- Homebrew (for formula/service install path)

## What It Does

- Watches system appearance changes using a native Swift/AppKit background agent.
- Applies the correct Terminal profile for light/dark mode.
- Always updates Terminal defaults (`Default Window Settings` and `Startup Window Settings`).
- Best-effort updates currently open tabs when Automation permission is available.
- Adds a shell-session correction hook so new sessions stay in sync.

## Scope

- Supported terminal app: Apple Terminal
- Supported OS: macOS (user-level LaunchAgent model)

## Architecture Overview

Core components:

- `lumoshell`: user-facing command router
- `lumoshell-apply`: mode/profile decision + Terminal settings writer
- `lumoshell-appearance-sync-agent`: event-driven sync daemon (Swift)
- `lumoshell-install` / `lumoshell-uninstall`: LaunchAgent and shell-hook lifecycle scripts

High-level flow:

```text
macOS appearance events
  -> lumoshell-appearance-sync-agent
  -> lumoshell-apply --reason theme-change
  -> Terminal defaults + best-effort open-tab update

new shell session (~/.zprofile managed block)
  -> lumoshell-apply --new-session --quiet
```

## Operational Efficiency

`lumoshell` is designed to be low-overhead and event-driven:

- Event-driven background agent (no polling loop)
- Small shell wrappers for install/apply lifecycle
- User-level LaunchAgent model

Current measured footprint (from local benchmark run):

- Compiled project disk footprint: about `119.57 KB`
- Runtime memory usage (appearance sync agent RSS): about `26.67 MB` peak

Reproduce/update these numbers with:

```sh
bash scripts/benchmark-footprint.sh
```

## CLI

```sh
lumoshell <command> [options]
```

Commands:

- `lumoshell apply [--reason REASON] [--new-session] [--dry-run] [--quiet]`
- `lumoshell install`
- `lumoshell uninstall`
- `lumoshell doctor`
- `lumoshell version`

Helper binaries:

- `lumoshell-apply`
- `lumoshell-install`
- `lumoshell-uninstall`
- `lumoshell-appearance-sync-agent`

## Homebrew Install and Uninstall (recommended)

### Install with Homebrew

Install from the official tap:

```sh
brew tap aakaashjois/lumoshell
brew install lumoshell
```

If Homebrew does not resolve the short formula name in your environment, use:

```sh
brew install aakaashjois/lumoshell/lumoshell
```

`brew install lumoshell` runs `lumoshell install` in `post_install` and attempts to enroll/start the user LaunchAgent automatically.

If startup enrollment fails due to user-session context, run:

```sh
lumoshell install
```

Service lifecycle commands:

```sh
brew services start lumoshell
brew services stop lumoshell
brew services restart lumoshell
brew services list
```

### Uninstall with Homebrew

```sh
lumoshell uninstall
brew uninstall --formula lumoshell
```

## Manual Install and Uninstall (without Homebrew)

### Install without Homebrew

Build the sync agent:

```sh
cd src/appearance-sync-agent
swift build -c release
```

Install binaries on `PATH` (example):

```sh
cp src/appearance-sync-agent/.build/release/lumoshell-appearance-sync-agent /usr/local/bin/
cp bin/lumoshell /usr/local/bin/
cp bin/lumoshell-apply /usr/local/bin/
cp bin/lumoshell-install /usr/local/bin/
cp bin/lumoshell-uninstall /usr/local/bin/
```

Then enroll startup behavior:

```sh
lumoshell install
```

### Uninstall without Homebrew

```sh
lumoshell uninstall
rm -f /usr/local/bin/lumoshell
rm -f /usr/local/bin/lumoshell-apply
rm -f /usr/local/bin/lumoshell-install
rm -f /usr/local/bin/lumoshell-uninstall
rm -f /usr/local/bin/lumoshell-appearance-sync-agent
```

## Configuration

Environment variables:

- `MAC_TERMINAL_LIGHT_PROFILE` (default `Basic`)
- `MAC_TERMINAL_DARK_PROFILE` (default `Pro`)

Set them in your shell config (for example `~/.zprofile`). Values are picked up automatically on the next appearance change or new shell session.

## Permissions and Behavior

If Terminal Automation permission is denied:

- Defaults are still updated.
- Open-tab live updates are skipped.
- The tool continues in defaults-only mode and emits a warning.

## Security Notes

- Runs as the logged-in user; no root daemon required.
- Installer prefers colocated trusted helper binaries by default.
- Optional PATH lookup (`LUMOSHELL_ALLOW_PATH_LOOKUP=1`) is gated and hardened:
  - accepted binaries/parent dirs must be owned by `root` or the current user
  - world-writable binaries/parent dirs are rejected

Install mode trust boundaries:

- Local/manual install trusts your local checkout and shell environment.
- Homebrew install additionally trusts formula source and brew install lifecycle.

## Validation and Testing

Primary verification script:

```sh
bash scripts/verify.sh
```

This checks plist validity, apply dry-run, Swift build/tests, shell install/uninstall tests, and wrapper smoke checks.

Local Homebrew install test (without published tap):

```sh
./scripts/test-homebrew-local.sh
```

Useful options:

- `--cleanup` (remove installed formula/setup after test)
- `--no-reinstall` (verification only)
- `--tap <name>` (override temporary tap name)

## Contributing

Contributions are welcome.

- Open an issue for bugs, regressions, or feature requests.
- Keep changes focused and include verification steps.
- Run local checks before opening a PR:
  - `bash scripts/verify.sh`
  - `bash scripts/benchmark-footprint.sh`
- For changes that touch runtime behavior, startup flow, or binaries, verify there is no drastic regression in memory usage or compiled footprint.

For security-sensitive changes (installer paths, launchd, shell hooks), include threat-model notes in the PR description.

See `CONTRIBUTING.md` for full contributor guidance.

## Troubleshooting

- Check status and paths:
  - `lumoshell doctor`
- Validate LaunchAgent plist:
  - `plutil -lint launchd/com.user.lumoshell-appearance-sync-agent.plist`
- If launch enrollment did not happen during Homebrew install:
  - run `lumoshell install` manually

## License

This project is licensed under the MIT License. See `LICENSE`.

## Security

See `SECURITY.md` for vulnerability reporting and security expectations.

## Disclaimer

This software is provided on an "AS IS" basis, without warranties or conditions of any kind. To the fullest extent permitted by law, the author disclaims liability for any issues, damages, or data loss arising from its use.

