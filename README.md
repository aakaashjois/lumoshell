<div align="center">
  <img src="assets/icon.svg" width="128" height="128" alt="Lumoshell Icon">
  <h1>Lumoshell</h1>
  <p>
    <a href="https://github.com/aakaashjois/lumoshell/releases"><img src="https://badgen.net/github/release/aakaashjois/lumoshell" alt="Release"></a>
    <a href="https://github.com/aakaashjois/lumoshell/blob/main/LICENSE"><img src="https://badgen.net/badge/license/MIT/blue" alt="License: MIT"></a>
    <a href="https://www.apple.com/macos/"><img src="https://badgen.net/badge/platform/macOS/black" alt="macOS"></a>
    <a href="https://github.com/aakaashjois/lumoshell"><img src="https://badgen.net/badge/homebrew/aakaashjois%2Flumoshell/orange" alt="Homebrew Tap"></a>
    <a href="https://github.com/aakaashjois/lumoshell/actions"><img src="https://badgen.net/github/checks/aakaashjois/lumoshell/main" alt="CI"></a>
  </p>

  <h3>The terminal appearance switcher that macOS is missing. 🌗</h3>
  
  <p><em>No more squinting at a dark terminal in broad daylight, or burning your eyes on a glaring white screen at 2 AM.</em></p>
</div>

<br>

Lumoshell effortlessly bridges the gap between your system's appearance and Apple Terminal, keeping your active sessions perfectly in sync with macOS light and dark modes—instantly and automatically.

https://github.com/user-attachments/assets/96e7e153-38cc-4c3a-8ae6-f7d19497f736

## ⚡ Quick Install

Simply provide this GitHub repository link to an AI agent and ask it to install and configure Lumoshell for you. For example, you can use the following prompt:

> "install https://github.com/aakaashjois/lumoshell using brew and set it up for me."

## 🛠️ Manual Install

```sh
brew tap aakaashjois/lumoshell https://github.com/aakaashjois/lumoshell
brew trust aakaashjois/lumoshell
brew install lumoshell
lumoshell setup
```

## 🌟 At A Glance

- Apple Terminal + macOS only
- Event-driven sync agent (no polling loop)
- Keeps defaults and new sessions aligned to active theme
- Best-effort live updates for open tabs (with Automation permission)

## 💻 Common Commands

- `lumoshell setup`: interactively select the Terminal profiles to use for Light and Dark modes.
- `lumoshell setup --list`: list all available Terminal profiles.
- `lumoshell setup --light <profile> --dark <profile>`: non-interactively configure Terminal profiles.
- `lumoshell setup --reset`: clear the saved Light and Dark profiles.
- `lumoshell setup --remove`: uninstall the background agent and shell hook.
- `lumoshell status`: print the currently saved light/dark profile mapping.
- `lumoshell logs`: print appearance sync logs from the last hour.
- `lumoshell doctor`: run environment and path checks to diagnose setup issues.

## 🤖 Notes for AI Agents

If you are an AI agent setting up Lumoshell for a user, you cannot use the interactive TUI. Use the following workflow:
1. **Discover Profiles**: Run `lumoshell setup --list` to read the user's available Apple Terminal profiles.
2. **Configure (Non-Interactive)**: Run `lumoshell setup --light "<light_profile>" --dark "<dark_profile>"` to configure the application without a TUI.
3. If the user does not specify preferred profiles, reasonable defaults are `Basic` for light mode and `Pro` for dark mode.

## 📚 Documentation

- Start here: [`docs/README.md`](docs/README.md)
- Installation: [`docs/installation.md`](docs/installation.md)
- Build from source: [`docs/build-from-source.md`](docs/build-from-source.md)
- Configuration: [`docs/configuration.md`](docs/configuration.md)
- CLI reference: [`docs/cli.md`](docs/cli.md)
- Architecture and internals: [`docs/architecture.md`](docs/architecture.md)
- Security model: [`docs/security.md`](docs/security.md)
- Validation and testing: [`docs/testing.md`](docs/testing.md)
- Troubleshooting: [`docs/troubleshooting.md`](docs/troubleshooting.md)

## 📜 Project Policies

- Contributing guide: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Security policy: [`docs/security.md`](docs/security.md)
- License: [`LICENSE`](LICENSE)

## 🙏 Acknowledgements

The native Swift appearance sync daemon's event listener architecture was heavily inspired by the approach used in [cormacrelf/dark-notify](https://github.com/cormacrelf/dark-notify).

