#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_LABEL="com.user.lumoshell-appearance-sync-agent"
AGENT_BINARY="$ROOT_DIR/src/appearance-sync-agent/.build/release/lumoshell-appearance-sync-agent"

SAMPLE_SECONDS=20
SAMPLE_INTERVAL_SECONDS=1
STARTUP_WINDOW_SECONDS=5
SKIP_BUILD=0
JSON_OUT="$ROOT_DIR/docs/benchmarks/efficiency-footprint.json"
MD_OUT="$ROOT_DIR/docs/benchmarks/efficiency-footprint.md"

TMP_FILES=()

cleanup_tmp_files() {
  local tmp_file
  for tmp_file in "${TMP_FILES[@]}"; do
    rm -f "$tmp_file"
  done
}

trap cleanup_tmp_files EXIT

usage() {
  cat <<'EOF'
Usage: scripts/benchmark-footprint.sh [options]

Measures local/install disk footprint and agent RSS memory footprint.

Options:
  --sample-seconds <n>           Sample duration in seconds (default: 20)
  --sample-interval-seconds <n>  RSS sampling interval in seconds (default: 1)
  --startup-window-seconds <n>   Startup window used for peak startup RSS (default: 5)
  --json-out <path>              Output JSON path (default: docs/benchmarks/efficiency-footprint.json)
  --md-out <path>                Output Markdown path (default: docs/benchmarks/efficiency-footprint.md)
  --skip-build                   Do not build Swift agent if missing
  -h, --help                     Show this help
EOF
}

ensure_positive_int() {
  local value="$1"
  local name="$2"
  if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]]; then
    echo "$name must be a positive integer: $value" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sample-seconds)
      SAMPLE_SECONDS="${2:-}"
      shift 2
      ;;
    --sample-interval-seconds)
      SAMPLE_INTERVAL_SECONDS="${2:-}"
      shift 2
      ;;
    --startup-window-seconds)
      STARTUP_WINDOW_SECONDS="${2:-}"
      shift 2
      ;;
    --json-out)
      JSON_OUT="${2:-}"
      shift 2
      ;;
    --md-out)
      MD_OUT="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
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

ensure_positive_int "$SAMPLE_SECONDS" "--sample-seconds"
ensure_positive_int "$SAMPLE_INTERVAL_SECONDS" "--sample-interval-seconds"
ensure_positive_int "$STARTUP_WINDOW_SECONDS" "--startup-window-seconds"

if [[ "$SAMPLE_INTERVAL_SECONDS" -gt "$SAMPLE_SECONDS" ]]; then
  echo "--sample-interval-seconds cannot be greater than --sample-seconds" >&2
  exit 1
fi

mkdir -p "$(dirname "$JSON_OUT")" "$(dirname "$MD_OUT")"

if [[ ! -x "$AGENT_BINARY" && "$SKIP_BUILD" -eq 0 ]]; then
  if command -v swift >/dev/null 2>&1; then
    echo "[build] Building appearance sync agent (release)"
    (
      cd "$ROOT_DIR/src/appearance-sync-agent"
      swift build -c release
    )
  fi
fi

add_size_entry() {
  local output_file="$1"
  local label="$2"
  local path="$3"
  if [[ -e "$path" ]]; then
    local bytes
    bytes="$(stat -f%z "$path")"
    printf "%s\t%s\t%s\n" "$label" "$path" "$bytes" >>"$output_file"
  fi
}

sample_pid_rss() {
  local pid="$1"
  local seconds="$2"
  local interval="$3"
  local output_file="$4"
  local iterations=$((seconds / interval))
  local i

  : >"$output_file"
  for ((i = 0; i < iterations; i++)); do
    if ! ps -p "$pid" >/dev/null 2>&1; then
      break
    fi
    local rss_kb
    rss_kb="$(ps -o rss= -p "$pid" | awk '{print $1}')"
    if [[ "$rss_kb" =~ ^[0-9]+$ ]]; then
      echo "$rss_kb" >>"$output_file"
    fi
    sleep "$interval"
  done
}

summarize_samples() {
  local samples_file="$1"
  local startup_rows="$2"
  local summary_file="$3"

  local total_count min_kb max_kb avg_kb startup_peak_kb
  total_count="$(awk 'END { print NR + 0 }' "$samples_file")"
  min_kb="$(awk 'NR==1{m=$1} NR>1 && $1<m {m=$1} END {print m + 0}' "$samples_file")"
  max_kb="$(awk 'NR==1{m=$1} NR>1 && $1>m {m=$1} END {print m + 0}' "$samples_file")"
  avg_kb="$(awk '{s+=$1} END {if (NR>0) printf "%.0f", s/NR; else print 0}' "$samples_file")"
  startup_peak_kb="$(awk -v rows="$startup_rows" 'NR<=rows && $1>m {m=$1} END {print m + 0}' "$samples_file")"

  cat >"$summary_file" <<EOF
sample_count=$total_count
rss_min_kb=$min_kb
rss_avg_kb=$avg_kb
rss_peak_kb=$max_kb
rss_startup_peak_kb=$startup_peak_kb
EOF
}

LOCAL_SIZES="$(mktemp -t lumoshell-local-sizes)"
TMP_FILES+=("$LOCAL_SIZES")
: >"$LOCAL_SIZES"

add_size_entry "$LOCAL_SIZES" "bin/lumoshell" "$ROOT_DIR/bin/lumoshell"
add_size_entry "$LOCAL_SIZES" "bin/lumoshell-apply" "$ROOT_DIR/bin/lumoshell-apply"
add_size_entry "$LOCAL_SIZES" "bin/lumoshell-install" "$ROOT_DIR/bin/lumoshell-install"
add_size_entry "$LOCAL_SIZES" "bin/lumoshell-uninstall" "$ROOT_DIR/bin/lumoshell-uninstall"
add_size_entry "$LOCAL_SIZES" "launchd/com.user.lumoshell-appearance-sync-agent.plist" "$ROOT_DIR/launchd/com.user.lumoshell-appearance-sync-agent.plist"
if [[ -x "$AGENT_BINARY" ]]; then
  add_size_entry "$LOCAL_SIZES" "src/appearance-sync-agent/.build/release/lumoshell-appearance-sync-agent" "$AGENT_BINARY"
fi

INSTALLED_RAW_PATHS="$(mktemp -t lumoshell-installed-raw)"
INSTALLED_UNIQUE_PATHS="$(mktemp -t lumoshell-installed-unique)"
INSTALLED_SIZES="$(mktemp -t lumoshell-installed-sizes)"
TMP_FILES+=("$INSTALLED_RAW_PATHS" "$INSTALLED_UNIQUE_PATHS" "$INSTALLED_SIZES")

: >"$INSTALLED_RAW_PATHS"
: >"$INSTALLED_UNIQUE_PATHS"
: >"$INSTALLED_SIZES"

for exe in \
  lumoshell \
  lumoshell-apply \
  lumoshell-install \
  lumoshell-uninstall \
  lumoshell-appearance-sync-agent
do
  if command -v "$exe" >/dev/null 2>&1; then
    exe_path="$(command -v "$exe")"
    resolved_path="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$exe_path")"
    echo "$resolved_path" >>"$INSTALLED_RAW_PATHS"
  fi
done

if [[ -f "$HOME/Library/LaunchAgents/${AGENT_LABEL}.plist" ]]; then
  echo "$HOME/Library/LaunchAgents/${AGENT_LABEL}.plist" >>"$INSTALLED_RAW_PATHS"
fi

sort -u "$INSTALLED_RAW_PATHS" >"$INSTALLED_UNIQUE_PATHS"
while IFS= read -r installed_path; do
  if [[ -n "$installed_path" && -e "$installed_path" ]]; then
    add_size_entry "$INSTALLED_SIZES" "$(basename "$installed_path")" "$installed_path"
  fi
done <"$INSTALLED_UNIQUE_PATHS"

MEMORY_SOURCE="none"
MEMORY_PID=""
EPHEMERAL_PID=""
RSS_SAMPLES_FILE="$(mktemp -t lumoshell-rss-samples)"
MEMORY_SUMMARY_FILE="$(mktemp -t lumoshell-memory-summary)"
TMP_FILES+=("$RSS_SAMPLES_FILE" "$MEMORY_SUMMARY_FILE")
APPLY_PEAK_RSS_BYTES=-1

launchctl_pid="$(
  launchctl print "gui/$(id -u)/$AGENT_LABEL" 2>/dev/null \
    | awk '/pid = / {gsub(";", "", $3); print $3; exit}' \
    || true
)"

if [[ "$launchctl_pid" =~ ^[0-9]+$ ]] && ps -p "$launchctl_pid" >/dev/null 2>&1; then
  MEMORY_SOURCE="launchagent"
  MEMORY_PID="$launchctl_pid"
  echo "[memory] Sampling running LaunchAgent pid=$MEMORY_PID"
  sample_pid_rss "$MEMORY_PID" "$SAMPLE_SECONDS" "$SAMPLE_INTERVAL_SECONDS" "$RSS_SAMPLES_FILE"
elif [[ -x "$AGENT_BINARY" ]]; then
  MEMORY_SOURCE="ephemeral"
  echo "[memory] Sampling ephemeral agent process"
  "$AGENT_BINARY" --apply-cmd /usr/bin/true --quiet >/dev/null 2>&1 &
  EPHEMERAL_PID="$!"
  MEMORY_PID="$EPHEMERAL_PID"
  sleep 1
  sample_pid_rss "$MEMORY_PID" "$SAMPLE_SECONDS" "$SAMPLE_INTERVAL_SECONDS" "$RSS_SAMPLES_FILE"
  kill "$EPHEMERAL_PID" >/dev/null 2>&1 || true
else
  echo "[memory] Skipped: no running LaunchAgent and no local agent binary available" >&2
fi

startup_rows=$((STARTUP_WINDOW_SECONDS / SAMPLE_INTERVAL_SECONDS))
if [[ "$startup_rows" -lt 1 ]]; then
  startup_rows=1
fi

if [[ -s "$RSS_SAMPLES_FILE" ]]; then
  summarize_samples "$RSS_SAMPLES_FILE" "$startup_rows" "$MEMORY_SUMMARY_FILE"
else
  cat >"$MEMORY_SUMMARY_FILE" <<'EOF'
sample_count=0
rss_min_kb=-1
rss_avg_kb=-1
rss_peak_kb=-1
rss_startup_peak_kb=-1
EOF
fi

# shellcheck disable=SC1090
source "$MEMORY_SUMMARY_FILE"

if [[ -x "$ROOT_DIR/bin/lumoshell-apply" ]]; then
  APPLY_TIME_OUTPUT="$(mktemp -t lumoshell-apply-time)"
  TMP_FILES+=("$APPLY_TIME_OUTPUT")
  if /usr/bin/time -l "$ROOT_DIR/bin/lumoshell-apply" --dry-run --reason footprint-benchmark >/dev/null 2>"$APPLY_TIME_OUTPUT"; then
    parsed_rss="$(awk '/maximum resident set size/ {print $1; exit}' "$APPLY_TIME_OUTPUT")"
    if [[ "$parsed_rss" =~ ^[0-9]+$ ]]; then
      APPLY_PEAK_RSS_BYTES="$parsed_rss"
    fi
  fi
fi

TIMESTAMP_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
HOST_ARCH="$(uname -m)"
MACOS_VERSION="$(sw_vers -productVersion)"

python3 - "$LOCAL_SIZES" "$INSTALLED_SIZES" "$JSON_OUT" "$MD_OUT" "$TIMESTAMP_UTC" "$HOST_ARCH" "$MACOS_VERSION" "$MEMORY_SOURCE" "$MEMORY_PID" "$sample_count" "$rss_min_kb" "$rss_avg_kb" "$rss_peak_kb" "$rss_startup_peak_kb" "$SAMPLE_SECONDS" "$SAMPLE_INTERVAL_SECONDS" "$STARTUP_WINDOW_SECONDS" "$APPLY_PEAK_RSS_BYTES" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

local_sizes_path = pathlib.Path(sys.argv[1])
installed_sizes_path = pathlib.Path(sys.argv[2])
json_out = pathlib.Path(sys.argv[3])
md_out = pathlib.Path(sys.argv[4])
timestamp_utc = sys.argv[5]
host_arch = sys.argv[6]
macos_version = sys.argv[7]
memory_source = sys.argv[8]
memory_pid = sys.argv[9]
sample_count = int(sys.argv[10])
rss_min_kb = int(sys.argv[11])
rss_avg_kb = int(sys.argv[12])
rss_peak_kb = int(sys.argv[13])
rss_startup_peak_kb = int(sys.argv[14])
sample_seconds = int(sys.argv[15])
sample_interval_seconds = int(sys.argv[16])
startup_window_seconds = int(sys.argv[17])
apply_peak_rss_bytes = int(sys.argv[18])

def read_sizes(path: pathlib.Path):
    rows = []
    if not path.exists():
        return rows
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        label, file_path, raw_bytes = line.split("\t")
        rows.append(
            {
                "label": label,
                "path": file_path,
                "bytes": int(raw_bytes),
            }
        )
    return rows

def human_bytes(num: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    value = float(num)
    for unit in units:
        if value < 1024.0 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.2f} {unit}"
        value /= 1024.0
    return f"{num} B"

local_rows = read_sizes(local_sizes_path)
installed_rows = read_sizes(installed_sizes_path)

local_total = sum(row["bytes"] for row in local_rows)
installed_total = sum(row["bytes"] for row in installed_rows)

def nullable_kb(value: int):
    return None if value < 0 else value

def bytes_to_kb(value: int):
    if value < 0:
        return None
    return int(round(value / 1024))

report = {
    "generated_at_utc": timestamp_utc,
    "environment": {
        "platform": "macOS",
        "macos_version": macos_version,
        "architecture": host_arch,
    },
    "disk_footprint": {
        "local_repo_components": {
            "total_bytes": local_total,
            "total_human": human_bytes(local_total),
            "components": local_rows,
        },
        "installed_components": {
            "total_bytes": installed_total,
            "total_human": human_bytes(installed_total),
            "components": installed_rows,
        },
    },
    "memory_footprint": {
        "long_running_agent_rss": {
            "source": memory_source,
            "pid": memory_pid,
            "sampling": {
                "sample_seconds": sample_seconds,
                "sample_interval_seconds": sample_interval_seconds,
                "startup_window_seconds": startup_window_seconds,
                "sample_count": sample_count,
            },
            "rss_kb": {
                "min": nullable_kb(rss_min_kb),
                "avg": nullable_kb(rss_avg_kb),
                "peak": nullable_kb(rss_peak_kb),
                "startup_peak": nullable_kb(rss_startup_peak_kb),
            },
        },
        "apply_command_peak_rss": {
            "bytes": None if apply_peak_rss_bytes < 0 else apply_peak_rss_bytes,
            "kb": bytes_to_kb(apply_peak_rss_bytes),
        },
    },
}

def fmt_kb(value):
    if value is None:
        return "n/a"
    return f"{value} KB"

long_running = report["memory_footprint"]["long_running_agent_rss"]

lines = []
lines.append("# Efficiency Benchmark Report")
lines.append("")
lines.append(f"- Generated at (UTC): `{timestamp_utc}`")
lines.append(f"- Environment: `macOS {macos_version}` on `{host_arch}`")
lines.append("")

lines.append("## Memory Footprint")
lines.append("")
lines.append("### Long-running agent RSS")
lines.append("")
lines.append("| Metric | Value |")
lines.append("| --- | --- |")
lines.append(f"| Source | `{long_running['source']}` |")
lines.append(f"| PID | `{long_running['pid'] or 'n/a'}` |")
lines.append(
    f"| Samples | `{long_running['sampling']['sample_count']}` over "
    f"`{sample_seconds}s` (`{sample_interval_seconds}s` interval) |"
)
lines.append(f"| RSS min | `{fmt_kb(long_running['rss_kb']['min'])}` |")
lines.append(f"| RSS avg | `{fmt_kb(long_running['rss_kb']['avg'])}` |")
lines.append(f"| RSS peak | `{fmt_kb(long_running['rss_kb']['peak'])}` |")
lines.append(
    f"| RSS startup peak (first {startup_window_seconds}s) | "
    f"`{fmt_kb(long_running['rss_kb']['startup_peak'])}` |"
)
lines.append("")

lines.append("### One-shot apply command RSS")
lines.append("")
lines.append("| Metric | Value |")
lines.append("| --- | --- |")
lines.append(
    f"| `lumoshell-apply --dry-run` max RSS | "
    f"`{fmt_kb(report['memory_footprint']['apply_command_peak_rss']['kb'])}` |"
)
lines.append("")

json_out.write_text(json.dumps(report, indent=2) + "\n")

lines.append("## Disk Footprint (Local Repo Components)")
lines.append("")
lines.append(f"Total: `{local_total} bytes` (`{human_bytes(local_total)}`)")
lines.append("")
lines.append("| Component | Size (bytes) | Size (human) | Path |")
lines.append("| --- | ---: | ---: | --- |")
for row in local_rows:
    lines.append(f"| `{row['label']}` | `{row['bytes']}` | `{human_bytes(row['bytes'])}` | `{row['path']}` |")
if not local_rows:
    lines.append("| _none found_ | `0` | `0 B` | `n/a` |")
lines.append("")

lines.append("## Disk Footprint (Installed Components)")
lines.append("")
lines.append(f"Total: `{installed_total} bytes` (`{human_bytes(installed_total)}`)")
lines.append("")
lines.append("| Component | Size (bytes) | Size (human) | Path |")
lines.append("| --- | ---: | ---: | --- |")
for row in installed_rows:
    lines.append(f"| `{row['label']}` | `{row['bytes']}` | `{human_bytes(row['bytes'])}` | `{row['path']}` |")
if not installed_rows:
    lines.append("| _none found_ | `0` | `0 B` | `n/a` |")
lines.append("")

md_out.write_text("\n".join(lines) + "\n")
PY

echo "[ok] Wrote JSON report: $JSON_OUT"
echo "[ok] Wrote Markdown report: $MD_OUT"
