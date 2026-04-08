#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA_PATH="$ROOT_DIR/Formula/lumoshell.rb"
LABEL="com.user.lumoshell-appearance-sync-agent"
LAUNCH_AGENT_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
TAP_NAME="${LUMOSHELL_TEST_TAP:-$(id -un)/lumoshell-localtest}"

CLEANUP=0
REINSTALL=1
TAP_CREATED=0
TMP_FILES=()

cleanup_tmp_files() {
  local tmp_file
  for tmp_file in "${TMP_FILES[@]}"; do
    if [[ -d "$tmp_file" ]]; then
      rm -rf "$tmp_file"
    else
      rm -f "$tmp_file"
    fi
  done
}

ensure_launch_agent_file() {
  if [[ ! -f "$LAUNCH_AGENT_PATH" ]]; then
    echo "LaunchAgent missing after brew install; attempting fallback: lumoshell install"
    lumoshell install
  fi

  if [[ -f "$LAUNCH_AGENT_PATH" ]]; then
    plutil -lint "$LAUNCH_AGENT_PATH"
    return
  fi

  echo "Expected LaunchAgent missing: $LAUNCH_AGENT_PATH" >&2
  exit 1
}

trap cleanup_tmp_files EXIT

usage() {
  cat <<'EOF'
Usage: scripts/test-homebrew-local.sh [options]

Options:
  --no-reinstall   Skip uninstall/install and only run verification checks
  --cleanup        Uninstall formula and remove launch setup at the end
  --tap <name>     Override tap name (default: <user>/lumoshell-localtest)
  -h, --help       Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-reinstall)
      REINSTALL=0
      shift
      ;;
    --cleanup)
      CLEANUP=1
      shift
      ;;
    --tap)
      TAP_NAME="${2:-}"
      if [[ -z "$TAP_NAME" ]]; then
        echo "--tap requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$FORMULA_PATH" ]]; then
  echo "Formula not found: $FORMULA_PATH" >&2
  exit 1
fi

echo "[1/7] preflight"
command -v brew >/dev/null
brew --version >/dev/null
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_SANDBOX=1

if [[ "$REINSTALL" -eq 1 ]]; then
  echo "[2/7] ensure local tap exists ($TAP_NAME)"
  if ! brew tap | rg -x "$TAP_NAME" >/dev/null; then
    brew tap-new "$TAP_NAME"
    TAP_CREATED=1
  fi
  TAP_REPO="$(brew --repository "$TAP_NAME")"
  mkdir -p "$TAP_REPO/Formula"
  cp "$FORMULA_PATH" "$TAP_REPO/Formula/lumoshell.rb"

  echo "[2.5/7] build local payload (release-style archive)"
  swift build -c release --package-path "$ROOT_DIR/src/appearance-sync-agent"
  LOCAL_PAYLOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lumoshell-local-payload.XXXXXX")"
  TMP_FILES+=("$LOCAL_PAYLOAD_DIR")
  cp "$ROOT_DIR/src/appearance-sync-agent/.build/release/lumoshell-appearance-sync-agent" "$LOCAL_PAYLOAD_DIR/"
  cp "$ROOT_DIR/bin/lumoshell" "$LOCAL_PAYLOAD_DIR/"
  cp "$ROOT_DIR/bin/lumoshell-apply" "$LOCAL_PAYLOAD_DIR/"
  cp "$ROOT_DIR/bin/lumoshell-install" "$LOCAL_PAYLOAD_DIR/"
  cp "$ROOT_DIR/bin/lumoshell-uninstall" "$LOCAL_PAYLOAD_DIR/"
  chmod +x "$LOCAL_PAYLOAD_DIR"/lumoshell*

  LOCAL_ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/lumoshell-local-release.XXXXXX.tar.gz")"
  TMP_FILES+=("$LOCAL_ARCHIVE")
  tar -czf "$LOCAL_ARCHIVE" -C "$LOCAL_PAYLOAD_DIR" .
  LOCAL_ARCHIVE_SHA="$(shasum -a 256 "$LOCAL_ARCHIVE" | awk '{print $1}')"
  LOCAL_RELEASE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lumoshell-local-release-dir.XXXXXX")"
  TMP_FILES+=("$LOCAL_RELEASE_DIR")
  cp "$LOCAL_ARCHIVE" "$LOCAL_RELEASE_DIR/lumoshell-darwin-universal.tar.gz"
  printf "%s  %s\n" "$LOCAL_ARCHIVE_SHA" "lumoshell-darwin-universal.tar.gz" > "$LOCAL_RELEASE_DIR/SHA256SUMS.txt"
  LOCAL_RELEASE_BASE_URL="file://$LOCAL_RELEASE_DIR"

  echo "[3/7] uninstall existing formula (if present)"
  brew uninstall --formula lumoshell >/dev/null 2>&1 || true

  echo "[4/7] install local formula from tap (local archive source)"
  LUMOSHELL_RELEASE_BASE_URL="$LOCAL_RELEASE_BASE_URL" brew install "$TAP_NAME/lumoshell"
else
  echo "[2/7] skip reinstall"
  echo "[3/7] skip reinstall"
  echo "[4/7] skip reinstall"
fi

echo "[5/7] verify formula and CLI"
brew list --versions lumoshell
command -v lumoshell >/dev/null
lumoshell version
lumoshell doctor

echo "[6/7] verify launch agent file"
ensure_launch_agent_file

echo "[7/7] verify launchctl service state"
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "LaunchAgent is loaded: $LABEL"
else
  echo "LaunchAgent not loaded: $LABEL" >&2
  echo "Try: lumoshell install" >&2
  exit 1
fi

echo "[8/8] smoke apply"
lumoshell apply --dry-run --reason homebrew-local-test

if [[ "$CLEANUP" -eq 1 ]]; then
  echo "[cleanup] uninstalling"
  lumoshell uninstall || true
  brew uninstall --formula lumoshell || true
  if [[ "$TAP_CREATED" -eq 1 ]]; then
    brew untap "$TAP_NAME" || true
  fi
fi

echo "Homebrew local formula test completed successfully."
