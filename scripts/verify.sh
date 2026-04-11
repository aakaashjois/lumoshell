#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/9] lint plist"
plutil -lint "$ROOT_DIR/launchd/com.user.lumoshell-appearance-sync-agent.plist"

echo "[2/9] dry-run apply"
"$ROOT_DIR/bin/lumoshell-apply" --dry-run

echo "[3/9] build appearance sync agent"
(
  cd "$ROOT_DIR/src/appearance-sync-agent"
  swift build -c release
  echo "[4/9] run appearance sync agent tests"
  swift test
)

echo "[5/9] check appearance sync agent architecture"
file "$ROOT_DIR/src/appearance-sync-agent/.build/release/lumoshell-appearance-sync-agent"

echo "[6/9] shell install/uninstall tests"
bash "$ROOT_DIR/tests/install_uninstall_test.sh"

echo "[7/9] cli contract regression tests"
bash "$ROOT_DIR/tests/cli_contract_test.sh"

echo "[8/9] version resolution regression tests"
bash "$ROOT_DIR/tests/version_resolution_test.sh"

echo "[9/9] smoke wrapper"
"$ROOT_DIR/bin/lumoshell" version
"$ROOT_DIR/bin/lumoshell" apply --dry-run

echo "verification script completed"
