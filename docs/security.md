# Security

## Security Model and Hardening

- Runs as the logged-in user; no root daemon required.
- Installer prefers colocated trusted helper binaries by default.
- Optional PATH lookup (`LUMOSHELL_ALLOW_PATH_LOOKUP=1`) is gated and hardened:
  - accepted binaries/parent dirs must be owned by `root` or the current user
  - world-writable binaries/parent dirs are rejected

## Install Mode Trust Boundaries

- Local/manual install trusts your local checkout and shell environment.
- Homebrew install additionally trusts formula source and brew install lifecycle.

## Supported Scope

This project is a local macOS utility. The primary security-sensitive areas are:

- install/uninstall scripts (`bin/lumoshell-install`, `bin/lumoshell-uninstall`)
- profile apply logic (`bin/lumoshell-apply`)
- launchd integration (`launchd/*.plist`)
- sync agent execution path (`src/appearance-sync-agent`)

## Reporting a Vulnerability

Please do not open public issues for suspected vulnerabilities.

Instead, report privately with:

- affected version or commit
- reproduction steps
- impact assessment
- suggested fix (if available)

If private reporting channels are not yet configured for this repository, open an issue with minimal detail and request a secure contact method.

## Security Expectations

- Default behavior should remain safe-by-default and least-privilege.
- Startup persistence changes must be explicit and reversible.
- Any optional trust expansion (for example PATH-based lookup) must stay opt-in and hardened.
- New command execution paths should avoid shell injection risks and use explicit argument passing where possible.

## Additional Hardening Notes

- `LUMOSHELL_ALLOW_PATH_LOOKUP=1` is optional and should only be used in trusted environments.
- Homebrew install and local/manual install have different trust boundaries; document changes affecting either path.