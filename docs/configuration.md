# Configuration

## Set Profiles

Set profiles interactively with the `setup` command (recommended):

```sh
lumoshell setup
```

Defaults:

- Light mode profile: `Basic`
- Dark mode profile: `Pro`

Inspect/reset saved profile configuration:

```sh
lumoshell status
lumoshell setup --reset
```

## Environment Variable Overrides (optional)

- `LUMOSHELL_PROFILE_LIGHT` (default `Basic`)
- `LUMOSHELL_PROFILE_DARK` (default `Pro`)

Set env vars in your shell config (for example `~/.zprofile`) if you need temporary or machine-specific overrides. Env vars take precedence over saved command-based profile settings.

## Permissions and Behavior

If Terminal Automation permission is denied:

- Defaults are still updated.
- Open-tab live updates are skipped.
- The tool continues in defaults-only mode and emits a warning.
