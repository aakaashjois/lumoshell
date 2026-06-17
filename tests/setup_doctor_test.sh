#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT_DIR/bin/lumoshell"

fail() {
  echo "test failed: $1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$msg (missing: $needle)"
}

echo "[setup_doctor_test] setup state mutation"

# Cleanup any existing state for test isolation
"$CLI" setup --reset >/dev/null 2>&1 || true

"$CLI" setup --light "Basic" >/dev/null
light_val=$(defaults read com.user.lumoshell LightProfile 2>/dev/null || echo "MISSING")
[[ "$light_val" == "Basic" ]] || fail "setup --light failed to persist to UserDefaults"

"$CLI" setup --dark "Ocean" >/dev/null
dark_val=$(defaults read com.user.lumoshell DarkProfile 2>/dev/null || echo "MISSING")
[[ "$dark_val" == "Ocean" ]] || fail "setup --dark failed to persist to UserDefaults"

"$CLI" setup --reset >/dev/null
defaults read com.user.lumoshell >/dev/null 2>&1 && fail "setup --reset failed to delete domain" || true

echo "[setup_doctor_test] doctor diagnostics"

doctor_out="$("$CLI" doctor)"
assert_contains "$doctor_out" "lumoshell version:" "doctor missing version check"
assert_contains "$doctor_out" "Terminal profile mode detection:" "doctor missing mode detection check"

echo "[setup_doctor_test] ok"
