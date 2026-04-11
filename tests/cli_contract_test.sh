#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT_DIR/bin/lumoshell"
APPLY="$ROOT_DIR/bin/lumoshell-apply"
FORMULA="$ROOT_DIR/Formula/lumoshell.rb"

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

echo "[cli_contract_test] help surface"
help_output="$("$CLI" help)"
assert_contains "$help_output" "apply [--dry-run] [--verbose]" "expected apply command in help output"
assert_contains "$help_output" "profile show" "expected profile show in help output"
assert_contains "$help_output" "logs" "expected logs command in help output"
assert_contains "$help_output" "doctor" "expected doctor command in help output"

apply_help="$("$APPLY" --help)"
assert_contains "$apply_help" "--new-session" "expected --new-session in apply help"
assert_contains "$apply_help" "--dry-run" "expected --dry-run in apply help"

echo "[cli_contract_test] removed flag rejection"
if "$CLI" apply --reason smoke-test >/dev/null 2>&1; then
  fail "apply should reject removed --reason flag"
fi

echo "[cli_contract_test] profile show arity validation"
if "$CLI" profile show extra >/dev/null 2>&1; then
  fail "profile show should reject unexpected positional args"
fi

echo "[cli_contract_test] formula caveat drift"
if rg -F -- "--reason" "$FORMULA" >/dev/null; then
  fail "Formula caveats should not mention removed --reason flag"
fi

echo "[cli_contract_test] ok"
