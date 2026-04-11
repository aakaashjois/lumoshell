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

write_noop_executable() {
  local path="$1"
  cat > "$path" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$path"
}

run_install_uninstall_idempotency_test() {
  local temp_home temp_bin zprofile start_count end_count
  temp_home="$(mktemp -d)"
  temp_bin="$temp_home/bin"
  mkdir -p "$temp_bin"

  write_noop_executable "$temp_bin/lumoshell-appearance-sync-agent"
  write_noop_executable "$temp_bin/lumoshell-apply"
  write_noop_executable "$temp_bin/launchctl"

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

  write_noop_executable "$temp_bin/launchctl"

  zprofile="$temp_home/.zprofile"
  cat > "$zprofile" <<'EOF'
export FOO="bar"
# >>> lumoshell managed block >>>
lumoshell-apply --new-session >/dev/null 2>&1 || true
EOF
  before_snapshot="$(<"$zprofile")"

  if HOME="$temp_home" PATH="$temp_bin:$PATH" "$UNINSTALL_SCRIPT"; then
    fail "uninstall should fail when markers are malformed"
  fi

  [[ -f "${zprofile}.bak" ]] || fail "expected backup file when malformed markers are detected"
  [[ "$(<"$zprofile")" == "$before_snapshot" ]] || fail "expected zprofile to remain unchanged on malformed markers"

  rm -rf "$temp_home"
}

run_homebrew_opt_path_stability_test() {
  local temp_home cellar_bin opt_bin zprofile launch_agent_path install_via_opt uninstall_via_opt
  temp_home="$(mktemp -d)"
  cellar_bin="$temp_home/Cellar/lumoshell/9.9.9/bin"
  opt_bin="$temp_home/opt/homebrew/bin"
  mkdir -p "$cellar_bin" "$opt_bin"

  cp "$INSTALL_SCRIPT" "$cellar_bin/lumoshell-install"
  cp "$UNINSTALL_SCRIPT" "$cellar_bin/lumoshell-uninstall"
  chmod +x "$cellar_bin/lumoshell-install" "$cellar_bin/lumoshell-uninstall"

  write_noop_executable "$opt_bin/lumoshell-appearance-sync-agent"
  write_noop_executable "$opt_bin/lumoshell-apply"
  write_noop_executable "$opt_bin/launchctl"

  ln -s "$cellar_bin/lumoshell-install" "$opt_bin/lumoshell-install"
  ln -s "$cellar_bin/lumoshell-uninstall" "$opt_bin/lumoshell-uninstall"

  install_via_opt="$opt_bin/lumoshell-install"
  uninstall_via_opt="$opt_bin/lumoshell-uninstall"
  launch_agent_path="$temp_home/Library/LaunchAgents/com.user.lumoshell-appearance-sync-agent.plist"
  zprofile="$temp_home/.zprofile"
  : > "$zprofile"

  HOME="$temp_home" PATH="$opt_bin:$PATH" "$install_via_opt"

  [[ -f "$launch_agent_path" ]] || fail "expected LaunchAgent file to be created"
  [[ -f "$zprofile" ]] || fail "expected zprofile to exist"

  grep -Fq "/opt/homebrew/bin/lumoshell-apply" "$launch_agent_path" || fail "LaunchAgent should reference stable opt-bin lumoshell-apply path"
  grep -Fq "/opt/homebrew/bin/lumoshell-appearance-sync-agent" "$launch_agent_path" || fail "LaunchAgent should reference stable opt-bin agent path"
  if grep -Fq "/Cellar/lumoshell/" "$launch_agent_path"; then
    fail "LaunchAgent should not reference versioned Cellar paths"
  fi

  grep -Fq "/opt/homebrew/bin/lumoshell-apply\" --new-session" "$zprofile" || fail "zprofile hook should reference stable opt-bin lumoshell-apply path"
  if grep -Fq "/Cellar/lumoshell/" "$zprofile"; then
    fail "zprofile hook should not reference versioned Cellar paths"
  fi

  HOME="$temp_home" PATH="$opt_bin:$PATH" "$uninstall_via_opt"
  rm -rf "$temp_home"
}

echo "[install_uninstall_test] idempotency"
run_install_uninstall_idempotency_test
echo "[install_uninstall_test] malformed marker protection"
run_malformed_marker_protection_test
echo "[install_uninstall_test] homebrew opt path stability"
run_homebrew_opt_path_stability_test
echo "[install_uninstall_test] ok"
