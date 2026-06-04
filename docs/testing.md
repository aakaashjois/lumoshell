# Validation and Testing

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


