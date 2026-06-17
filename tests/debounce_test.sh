#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_BIN="$ROOT_DIR/src/appearance-sync-agent/.build/release/lumoshell-appearance-sync-agent"

fail() {
  echo "test failed: $1" >&2
  exit 1
}

echo "[debounce_test] testing debounce window"

if [[ ! -x "$AGENT_BIN" ]]; then
  echo "Agent binary not found. Skipping debounce test."
  exit 0
fi

# We use a unique marker for the logs so we can easily filter them out.
# Start the agent in the background.
# We pass --quiet so it doesn't spam stdout, though logs still go to os_log.
"$AGENT_BIN" >/dev/null 2>&1 &
AGENT_PID=$!

# Ensure we clean up the agent when the test finishes
cleanup() {
  kill "$AGENT_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Give the agent a moment to start up
sleep 1

# Get the current time for log filtering (removed, using --last 1m)

# We can mock the appearance change by writing to the agent's app domain.
# UserDefaults.standard reads the app domain before the global domain.
# This avoids actually flashing the user's screen.
swift -e '
import Foundation
let center = DistributedNotificationCenter.default()
let defaults = UserDefaults(suiteName: "lumoshell-appearance-sync-agent")!

for i in 1...10 {
    if i % 2 == 0 {
        defaults.set("Dark", forKey: "AppleInterfaceStyle")
    } else {
        defaults.set("Light", forKey: "AppleInterfaceStyle")
    }
    center.postNotificationName(NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil, userInfo: nil, deliverImmediately: true)
    Thread.sleep(forTimeInterval: 0.02)
}
defaults.removeObject(forKey: "AppleInterfaceStyle")
'

# Wait for logs to flush
sleep 1

# We use --last 1m to avoid timezone/clock skew issues with --start
LOGS=$(log show --predicate "subsystem == 'com.user.lumoshell'" --info --debug --last 1m 2>/dev/null || true)

SKIP_COUNT=$(echo "$LOGS" | grep -c "skipping apply due to debounce window" || true)

if [[ "$SKIP_COUNT" -lt 1 ]]; then
  fail "Debounce test failed. Expected to see 'skipping apply due to debounce window' at least once when spamming theme changes."
fi

echo "[debounce_test] ok ($SKIP_COUNT events debounced)"
