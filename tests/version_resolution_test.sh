#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUMOSHELL_BIN="$ROOT_DIR/bin/lumoshell"

fail() {
  echo "test failed: $1" >&2
  exit 1
}

run_dev_fallback_resolution_test() {
  local version
  version="$("$LUMOSHELL_BIN" version)"
  [[ "$version" == "dev" ]] || fail "expected fallback version dev, got $version"
}

echo "[version_resolution_test] dev fallback"
run_dev_fallback_resolution_test
echo "[version_resolution_test] ok"
