#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/7] lint plist"
plutil -lint "$ROOT_DIR/launchd/com.user.lumoshell-appearance-sync-agent.plist"

echo "[2/7] dry-run apply"
"$ROOT_DIR/bin/lumoshell-apply" --dry-run

echo "[3/7] build appearance sync agent"
(
  cd "$ROOT_DIR/src/appearance-sync-agent"
  swift build -c release
  echo "[4/7] run appearance sync agent tests"
  swift test
)

echo "[5/7] check appearance sync agent architecture"
file "$ROOT_DIR/src/appearance-sync-agent/.build/release/lumoshell-appearance-sync-agent"

echo "[6/7] shell install/uninstall tests"
bash "$ROOT_DIR/tests/install_uninstall_test.sh"

echo "[7/7] smoke wrapper"
"$ROOT_DIR/bin/lumoshell" version
"$ROOT_DIR/bin/lumoshell" apply --dry-run

echo "verification script completed"
