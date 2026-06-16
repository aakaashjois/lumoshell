# Lumoshell

[![Release](https://img.shields.io/github/v/release/aakaashjois/lumoshell?display_name=tag)](https://github.com/aakaashjois/lumoshell/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS-black)](https://www.apple.com/macos/)
[![Homebrew Tap](https://img.shields.io/badge/homebrew-aakaashjois%2Flumoshell-orange)](https://github.com/aakaashjois/lumoshell)
[![CI](https://img.shields.io/github/actions/workflow/status/aakaashjois/lumoshell/release.yml?branch=main)](https://github.com/aakaashjois/lumoshell/actions)

**The terminal appearance switcher that macOS is missing.**

Lumoshell seamlessly bridges the gap between your system's appearance and Apple Terminal. No more squinting at a dark terminal in broad daylight or burning your eyes on a glaring white screen at 2 AM.

Lumoshell effortlessly keeps your terminal perfectly in sync with macOS light and dark modes, automatically.

https://github.com/user-attachments/assets/96e7e153-38cc-4c3a-8ae6-f7d19497f736

## Quick Install

Simply provide this GitHub repository link to an AI agent and ask it to install and configure Lumoshell for you. For example, you can use the following prompt:

> "Please install the mac terminal theme from https://github.com/aakaashjois/lumoshell and set it up for me."

## Manual Install

```sh
brew tap aakaashjois/lumoshell https://github.com/aakaashjois/lumoshell
brew trust aakaashjois/lumoshell
brew install lumoshell
lumoshell setup
```

## At A Glance

- Apple Terminal + macOS only
- Event-driven sync agent (no polling loop)
- Keeps defaults and new sessions aligned to active theme
- Best-effort live updates for open tabs (with Automation permission)

## Common Commands

- `lumoshell setup`: interactively select the Terminal profiles to use for Light and Dark modes.
- `lumoshell setup --reset`: clear the saved Light and Dark profiles.
- `lumoshell setup --remove`: uninstall the background agent and shell hook.
- `lumoshell status`: print the currently saved light/dark profile mapping.
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

## Acknowledgements

The native Swift appearance sync daemon's event listener architecture was heavily inspired by the approach used in [cormacrelf/dark-notify](https://github.com/cormacrelf/dark-notify).

