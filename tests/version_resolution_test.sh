#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUMOSHELL_BIN="$ROOT_DIR/bin/lumoshell"

fail() {
  echo "test failed: $1" >&2
  exit 1
}

run_git_tag_resolution_test() {
  local temp_repo
  temp_repo="$(mktemp -d)"

  mkdir -p "$temp_repo/bin"
  cp "$LUMOSHELL_BIN" "$temp_repo/bin/lumoshell"
  chmod +x "$temp_repo/bin/lumoshell"

  git -C "$temp_repo" -c init.defaultBranch=main init >/dev/null
  git -C "$temp_repo" config user.email "test@example.com"
  git -C "$temp_repo" config user.name "Test Runner"
  git -C "$temp_repo" remote add origin "git@github.com:aakaashjois/lumoshell.git"
  touch "$temp_repo/.keep"
  git -C "$temp_repo" add .keep
  git -C "$temp_repo" -c commit.gpgsign=false commit -m "init" >/dev/null
  git -C "$temp_repo" -c tag.gpgSign=false tag -a "v1.2.3" -m "v1.2.3" >/dev/null

  local version
  version="$("$temp_repo/bin/lumoshell" version)"
  [[ "$version" == "1.2.3" ]] || fail "expected git tag fallback version 1.2.3, got $version"
  rm -rf "$temp_repo"
}

run_cellar_path_resolution_test() {
  local temp_root cellar_bin
  temp_root="$(mktemp -d)"
  cellar_bin="$temp_root/Cellar/lumoshell/7.8.9/bin"
  mkdir -p "$cellar_bin"
  cp "$LUMOSHELL_BIN" "$cellar_bin/lumoshell"
  chmod +x "$cellar_bin/lumoshell"

  local version
  version="$("$cellar_bin/lumoshell" version)"
  [[ "$version" == "7.8.9" ]] || fail "expected Cellar-derived version 7.8.9, got $version"
  rm -rf "$temp_root"
}

echo "[version_resolution_test] git tag fallback"
run_git_tag_resolution_test
echo "[version_resolution_test] cellar path fallback"
run_cellar_path_resolution_test
echo "[version_resolution_test] ok"
