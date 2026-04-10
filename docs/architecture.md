# Architecture

## Scope

- Terminal support: Apple Terminal
- OS support: macOS (user-level LaunchAgent model)

## Why Lumoshell

Lumoshell is built to keep Terminal theming reliable without manual toggling:

- Real-time theme sync via native Swift/AppKit event handling
- Deterministic profile application for light and dark mode
- Default settings enforcement for startup and new windows
- Best-effort live tab updates when Automation permission is available
- Session-level consistency via shell hook

## Core Components

- `lumoshell`: user-facing command router
- `lumoshell-apply`: mode/profile decision + Terminal settings writer
- `lumoshell-appearance-sync-agent`: event-driven sync daemon (Swift)
- `lumoshell-install` / `lumoshell-uninstall`: LaunchAgent and shell-hook lifecycle scripts

## High-Level Flow

```text
macOS appearance events
  -> lumoshell-appearance-sync-agent
  -> lumoshell-apply
  -> Terminal defaults + best-effort open-tab update

new shell session (~/.zprofile managed block)
  -> lumoshell-apply --new-session
```

## Operational Efficiency

Lumoshell is designed to be low-overhead and event-driven:

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
