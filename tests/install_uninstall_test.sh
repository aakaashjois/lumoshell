#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/bin/lumoshell-install"
UNINSTALL_SCRIPT="$ROOT_DIR/bin/lumoshell-uninstall"
HOOK_START="# >>> lumoshell managed block >>>"
HOOK_END="# <<< lumoshell managed block <<<"

fail() {
  echo "test failed: $1" >&2
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  local msg="$3"
  [[ "$got" == "$want" ]] || fail "$msg (got=$got want=$want)"
}

run_install_uninstall_idempotency_test() {
  local temp_home temp_bin zprofile start_count end_count
  temp_home="$(mktemp -d)"
  temp_bin="$temp_home/bin"
  mkdir -p "$temp_bin"

  cat > "$temp_bin/lumoshell-appearance-sync-agent" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "$temp_bin/lumoshell-apply" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "$temp_bin/launchctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$temp_bin/lumoshell-appearance-sync-agent" "$temp_bin/lumoshell-apply" "$temp_bin/launchctl"

  zprofile="$temp_home/.zprofile"
  cat > "$zprofile" <<'EOF'
export PATH="$PATH:$HOME/.local/bin"
EOF

  HOME="$temp_home" PATH="$temp_bin:$PATH" LUMOSHELL_ALLOW_PATH_LOOKUP=1 "$INSTALL_SCRIPT"
  HOME="$temp_home" PATH="$temp_bin:$PATH" LUMOSHELL_ALLOW_PATH_LOOKUP=1 "$INSTALL_SCRIPT"

  start_count="$(awk -v marker="$HOOK_START" '$0 == marker { count++ } END { print count + 0 }' "$zprofile")"
  end_count="$(awk -v marker="$HOOK_END" '$0 == marker { count++ } END { print count + 0 }' "$zprofile")"
  assert_eq "$start_count" "1" "expected exactly one start marker after repeated install"
  assert_eq "$end_count" "1" "expected exactly one end marker after repeated install"

  HOME="$temp_home" PATH="$temp_bin:$PATH" "$UNINSTALL_SCRIPT"
  start_count="$(awk -v marker="$HOOK_START" '$0 == marker { count++ } END { print count + 0 }' "$zprofile")"
  end_count="$(awk -v marker="$HOOK_END" '$0 == marker { count++ } END { print count + 0 }' "$zprofile")"
  assert_eq "$start_count" "0" "expected no start marker after uninstall"
  assert_eq "$end_count" "0" "expected no end marker after uninstall"

  rm -rf "$temp_home"
}

run_malformed_marker_protection_test() {
  local temp_home temp_bin zprofile before_snapshot
  temp_home="$(mktemp -d)"
  temp_bin="$temp_home/bin"
  mkdir -p "$temp_bin"

  cat > "$temp_bin/launchctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$temp_bin/launchctl"

  zprofile="$temp_home/.zprofile"
  cat > "$zprofile" <<'EOF'
export FOO="bar"
# >>> lumoshell managed block >>>
lumoshell-apply --new-session --reason shell-session --quiet >/dev/null 2>&1 || true
EOF
  before_snapshot="$(<"$zprofile")"

  if HOME="$temp_home" PATH="$temp_bin:$PATH" "$UNINSTALL_SCRIPT"; then
    fail "uninstall should fail when markers are malformed"
  fi

  [[ -f "${zprofile}.bak" ]] || fail "expected backup file when malformed markers are detected"
  [[ "$(<"$zprofile")" == "$before_snapshot" ]] || fail "expected zprofile to remain unchanged on malformed markers"

  rm -rf "$temp_home"
}

echo "[install_uninstall_test] idempotency"
run_install_uninstall_idempotency_test
echo "[install_uninstall_test] malformed marker protection"
run_malformed_marker_protection_test
echo "[install_uninstall_test] ok"
