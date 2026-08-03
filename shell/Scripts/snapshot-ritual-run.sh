#!/bin/bash
# Snapshot-ritual reliability loop — wraps the app-generic `snapshot-spike`
# binary into the Phase 0 acceptance protocol (delivery-plan §15 Task 3, made
# app-agnostic): N consecutive invocations, per-run timing, failure count,
# p50/p95 against the 2–4 s ritual budget. Between runs an axdrive script
# (default: Esc) dismisses whatever sheet the menu action opened, so run i+1
# starts from a clean menu state.
#
# Usage:
#   snapshot-ritual-run.sh --bundle-id com.example.App --menu "File>Export as PDF…" \
#       [--runs 50] [--dismiss-keys esc] [--out DIR]
set -euo pipefail

BUNDLE_ID=""
MENU_PATH=""
RUNS=50
DISMISS_KEYS="esc"
OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --menu) MENU_PATH="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --dismiss-keys) DISMISS_KEYS="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$BUNDLE_ID" ] && [ -n "$MENU_PATH" ] || { echo "--bundle-id and --menu required" >&2; exit 2; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPIKE="$REPO_ROOT/shell/.build/debug/snapshot-spike"
DRIVE="$REPO_ROOT/shell/.build/debug/axdrive"

if [ -z "$OUT_DIR" ]; then
  SAFE_ID=$(echo "$BUNDLE_ID" | tr '.' '-')
  OUT_DIR="$REPO_ROOT/docs/notes/spike-snapshot-runs/$SAFE_ID-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT_DIR"

echo "== build =="
swift build --package-path "$REPO_ROOT/shell" --product snapshot-spike >/dev/null
swift build --package-path "$REPO_ROOT/shell" --product axdrive >/dev/null

echo "== $RUNS consecutive invocations of \"$MENU_PATH\" against $BUNDLE_ID =="
FAILURES=0
TIMES_FILE="$OUT_DIR/times.txt"
: > "$TIMES_FILE"

i=0
while [ "$i" -lt "$RUNS" ]; do
  i=$((i + 1))
  log=$(printf '%s/run-%03d.log' "$OUT_DIR" "$i")
  if "$SPIKE" --bundle-id "$BUNDLE_ID" --menu-path "$MENU_PATH" > "$log" 2>&1; then
    ok=$(grep -c "success: yes" "$log" || true)
    total=$(sed -n 's/.*(total \([0-9.]*\)s).*/\1/p' "$log" | tail -1)
    if [ "$ok" -ge 1 ] && [ -n "$total" ]; then
      echo "$total" >> "$TIMES_FILE"
      printf 'run %03d: %ss\n' "$i" "$total"
    else
      FAILURES=$((FAILURES + 1)); printf 'run %03d: FAIL (press/parse)\n' "$i"
    fi
  else
    FAILURES=$((FAILURES + 1)); printf 'run %03d: FAIL (spike exit)\n' "$i"
  fi
  # dismiss the sheet/menu state before the next run
  printf 'activate\nkey %s\nsleep 300\n' "$DISMISS_KEYS" | "$DRIVE" --bundle-id "$BUNDLE_ID" --script - >/dev/null 2>&1 || true
  sleep 0.3
done

SUMMARY="$OUT_DIR/summary.md"
{
  echo "# Snapshot-ritual reliability — $BUNDLE_ID — \"$MENU_PATH\" — $(date '+%Y-%m-%d %H:%M')"
  echo ""
  echo "- Runs: $RUNS   Failures: $FAILURES"
  if [ -s "$TIMES_FILE" ]; then
    sort -n "$TIMES_FILE" > "$TIMES_FILE.sorted"
    count=$(wc -l < "$TIMES_FILE.sorted" | tr -d ' ')
    p50=$(awk -v n="$count" 'NR == int((n*50+99)/100) {print; exit}' "$TIMES_FILE.sorted")
    p95=$(awk -v n="$count" 'NR == int((n*95+99)/100) {print; exit}' "$TIMES_FILE.sorted")
    min=$(head -1 "$TIMES_FILE.sorted"); max=$(tail -1 "$TIMES_FILE.sorted")
    echo "- Timing over $count successful runs: min ${min}s · p50 ${p50}s · p95 ${p95}s · max ${max}s"
    echo "- Budget: p95 must sit within the 2–4 s ritual window (delivery-plan Phase 0 bar: 50 consecutive, 0 failures, p95 in window, replicated on a second Mac)."
  fi
  echo ""
  echo "Raw per-run logs in this directory. Note: this loop measures menu-resolve → press → sheet-appearance"
  echo "and dismisses the sheet between runs; completing the export to a file is exercised when pointed at"
  echo "the real target app's export flow."
} > "$SUMMARY"

echo ""
cat "$SUMMARY"
