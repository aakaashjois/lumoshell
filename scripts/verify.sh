#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/11] lint plist"
plutil -lint "$ROOT_DIR/launchd/com.user.lumoshell-appearance-sync-agent.plist"

echo "[2/11] build appearance sync agent"
(
  cd "$ROOT_DIR/src/appearance-sync-agent"
  swift build -c release
)

echo "[4/11] dry-run apply"
"$ROOT_DIR/bin/lumoshell" apply --dry-run

echo "[5/11] check appearance sync agent architecture"
file "$ROOT_DIR/src/appearance-sync-agent/.build/release/lumoshell-appearance-sync-agent"

echo "[6/11] shell install/uninstall tests"
bash "$ROOT_DIR/tests/install_uninstall_test.sh"

echo "[7/11] cli contract regression tests"
bash "$ROOT_DIR/tests/cli_contract_test.sh"

echo "[8/11] version resolution regression tests"
bash "$ROOT_DIR/tests/version_resolution_test.sh"

echo "[8.1/11] setup and doctor tests"
bash "$ROOT_DIR/tests/setup_doctor_test.sh"

echo "[8.2/11] debounce tests"
bash "$ROOT_DIR/tests/debounce_test.sh"

echo "[9/11] smoke wrapper"
"$ROOT_DIR/bin/lumoshell" version
"$ROOT_DIR/bin/lumoshell" apply --dry-run

echo "[10/11] shellcheck"
shellcheck "$ROOT_DIR"/bin/* "$ROOT_DIR"/scripts/*.sh "$ROOT_DIR"/tests/*.sh

echo "[11/11] swiftlint"
(
  cd "$ROOT_DIR/src/appearance-sync-agent"
  swiftlint lint
)

echo "verification script completed"

