# Lumoshell

[![Release](https://img.shields.io/github/v/release/aakaashjois/lumoshell?display_name=tag)](https://github.com/aakaashjois/lumoshell/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS-black)](https://www.apple.com/macos/)
[![Homebrew Tap](https://img.shields.io/badge/homebrew-aakaashjois%2Flumoshell-orange)](https://github.com/aakaashjois/lumoshell)
[![CI](https://img.shields.io/github/actions/workflow/status/aakaashjois/lumoshell/release.yml?branch=main)](https://github.com/aakaashjois/lumoshell/actions)

`lumoshell` keeps Apple Terminal profiles aligned with macOS light/dark mode automatically.

## Quick Start

```sh
brew tap aakaashjois/lumoshell https://github.com/aakaashjois/lumoshell
brew install lumoshell
lumoshell install
```

## At A Glance

- Apple Terminal + macOS only
- Event-driven sync agent (no polling loop)
- Keeps defaults and new sessions aligned to active theme
- Best-effort live updates for open tabs (with Automation permission)

## Common Commands

- `lumoshell profile set light "Basic"`: set the profile to use when macOS is in light mode.
- `lumoshell profile set dark "Pro"`: set the profile to use when macOS is in dark mode.
- `lumoshell profile show`: print the currently saved light/dark profile mapping.
- `lumoshell logs`: print appearance sync logs from the last hour.
- `lumoshell doctor`: run environment and path checks to diagnose setup issues.

## Documentation

- Start here: [`docs/README.md`](docs/README.md)
- Installation: [`docs/installation.md`](docs/installation.md)
- Build from source: [`docs/build-from-source.md`](docs/build-from-source.md)
- Configuration: [`docs/configuration.md`](docs/configuration.md)
- CLI reference: [`docs/cli.md`](docs/cli.md)
- Architecture and internals: [`docs/architecture.md`](docs/architecture.md)
- Security model: [`docs/security.md`](docs/security.md)
- Validation and testing: [`docs/testing.md`](docs/testing.md)
- Troubleshooting: [`docs/troubleshooting.md`](docs/troubleshooting.md)

## Project Policies

- Contributing guide: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Security policy: [`docs/security.md`](docs/security.md)
- License: [`LICENSE`](LICENSE)

