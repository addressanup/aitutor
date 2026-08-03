#!/bin/bash
# Snapshot-ritual reliability loop — wraps the app-generic `snapshot-spike` binary
# into the Phase 0 acceptance protocol (delivery-plan §15 Task 3, made app-agnostic):
# N consecutive invocations, per-phase timing, failure count, p50/p95 against the
# 2–4 s ritual budget.
#
# A run counts as a success only if the spike reported "RITUAL ok" — meaning the
# artifact landed on disk AND focus returned to the app. An earlier version of this
# loop counted a menu press as success and parsed a total that was really a poll
# timeout, which is how 50 runs could report 0 failures without a single completed
# export. Phase timings are recorded so a budget overrun is attributable.
#
# Between runs the panel is dismissed through Accessibility, not keystrokes: a save
# panel is rendered out-of-process, so input posted to the target pid never reaches
# it and `key esc` silently does nothing.
#
# Usage:
#   snapshot-ritual-run.sh --bundle-id com.example.App --menu "File>Export as PDF…" \
#       [--runs 50] [--save-to DIR] [--confirm-button Save] [--confirm-method ax|click|return] \
#       [--pre "type z"] [--dismiss CancelButton] [--out DIR]
set -euo pipefail

BUNDLE_ID=""
MENU_PATH=""
RUNS=50
SAVE_TO="/tmp/aitutor-spike-out"
CONFIRM_BUTTON="Save"
CONFIRM_METHOD=""
PRE_KEYS=""
DISMISS="CancelButton"
OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --menu) MENU_PATH="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --save-to) SAVE_TO="$2"; shift 2 ;;
    --confirm-button) CONFIRM_BUTTON="$2"; shift 2 ;;
    --confirm-method) CONFIRM_METHOD="$2"; shift 2 ;;
    --pre) PRE_KEYS="$2"; shift 2 ;;
    --dismiss) DISMISS="$2"; shift 2 ;;
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
mkdir -p "$OUT_DIR" "$SAVE_TO"

echo "== build =="
swift build --package-path "$REPO_ROOT/shell" --product snapshot-spike >/dev/null
swift build --package-path "$REPO_ROOT/shell" --product axdrive >/dev/null

echo "== $RUNS consecutive rituals of \"$MENU_PATH\" against $BUNDLE_ID =="
FAILURES=0
TIMES_FILE="$OUT_DIR/times.txt"
PHASES_FILE="$OUT_DIR/phases.tsv"
FAILPHASE_FILE="$OUT_DIR/failed-phases.txt"
: > "$TIMES_FILE"; : > "$FAILPHASE_FILE"
printf 'run\tresolve\tpress\tpanel\tfill\tconfirm\tfile\tfocus\ttotal\n' > "$PHASES_FILE"

i=0
while [ "$i" -lt "$RUNS" ]; do
  i=$((i + 1))
  log=$(printf '%s/run-%03d.log' "$OUT_DIR" "$i")
  # Optional per-run preparation, e.g. dirtying a document so that Save has something to
  # write. Without it a "save" ritual over an unmodified document is a silent no-op and
  # the loop measures nothing at all.
  if [ -n "$PRE_KEYS" ]; then
    printf 'activate\n%s\nsleep 200\n' "$PRE_KEYS" | "$DRIVE" --bundle-id "$BUNDLE_ID" --script - >/dev/null 2>&1 || true
  fi
  set +e
  # No --filename: AX setValue on a save panel's name field updates the display but does
  # not bind to the panel's model, so dictating a per-run name would be a fiction. The
  # spike reads the name the app actually intends and proves the artifact belongs to this
  # run by mtime instead.
  "$SPIKE" --bundle-id "$BUNDLE_ID" --menu-path "$MENU_PATH" \
           --save-to "$SAVE_TO" --confirm-button "$CONFIRM_BUTTON" \
           ${CONFIRM_METHOD:+--confirm-method "$CONFIRM_METHOD"} > "$log" 2>&1
  set -e

  # Success is the ritual completing, not the menu press landing.
  if grep -q "RITUAL ok" "$log"; then
    total=$(sed -n 's/.*RITUAL ok — total \([0-9.]*\)s.*/\1/p' "$log" | tail -1)
    echo "$total" >> "$TIMES_FILE"
    phases=$(sed -n 's/.*PHASES resolve=\([0-9.]*\) press=\([0-9.]*\) panel=\([0-9.]*\) fill=\([0-9.]*\) confirm=\([0-9.]*\) file=\([0-9.]*\) focus=\([0-9.]*\).*/\1\t\2\t\3\t\4\t\5\t\6\t\7/p' "$log" | tail -1)
    printf '%d\t%s\t%s\n' "$i" "$phases" "$total" >> "$PHASES_FILE"
    printf 'run %03d: %ss\n' "$i" "$total"
  else
    FAILURES=$((FAILURES + 1))
    phase=$(sed -n 's/.*phase=\([a-z]*\) total=.*/\1/p' "$log" | tail -1)
    echo "${phase:-unknown}" >> "$FAILPHASE_FILE"
    printf 'run %03d: FAIL (%s)\n' "$i" "${phase:-unknown}"
  fi

  # Reset state through AX before the next run.
  printf 'press %s\nsleep 300\n' "$DISMISS" | "$DRIVE" --bundle-id "$BUNDLE_ID" --script - >/dev/null 2>&1 || true
  sleep 0.3
done

# Nearest-rank percentile over a column of a whitespace-separated file.
pct() { # $1=file $2=column $3=percentile
  awk -v c="$2" '{print $c}' "$1" | grep -E '^[0-9.]+$' | sort -n > "$OUT_DIR/.p.tmp"
  local n; n=$(wc -l < "$OUT_DIR/.p.tmp" | tr -d ' ')
  [ "$n" -gt 0 ] || { echo "—"; return; }
  awk -v n="$n" -v p="$3" 'NR == int((n*p+99)/100) {print; exit}' "$OUT_DIR/.p.tmp"
}

SUMMARY="$OUT_DIR/summary.md"
{
  echo "# Snapshot-ritual reliability — $BUNDLE_ID — \"$MENU_PATH\" — $(date '+%Y-%m-%d %H:%M')"
  echo ""
  echo "- Runs: $RUNS   Failures: $FAILURES"
  echo "- A run counts as a success only when the artifact landed on disk **and** focus returned."
  if [ -s "$TIMES_FILE" ]; then
    sort -n "$TIMES_FILE" > "$TIMES_FILE.sorted"
    count=$(wc -l < "$TIMES_FILE.sorted" | tr -d ' ')
    p50=$(awk -v n="$count" 'NR == int((n*50+99)/100) {print; exit}' "$TIMES_FILE.sorted")
    p95=$(awk -v n="$count" 'NR == int((n*95+99)/100) {print; exit}' "$TIMES_FILE.sorted")
    min=$(head -1 "$TIMES_FILE.sorted"); max=$(tail -1 "$TIMES_FILE.sorted")
    echo "- Total over $count successful rituals: min ${min}s · p50 ${p50}s · p95 ${p95}s · max ${max}s"
    echo ""
    echo "## Per-phase p50 / p95 (cumulative seconds from t0)"
    echo ""
    echo "| Phase | p50 | p95 |"
    echo "|---|---|---|"
    col=2
    for phase in resolve press panel fill confirm file focus; do
      echo "| $phase | $(pct "$PHASES_FILE" $col 50) | $(pct "$PHASES_FILE" $col 95) |"
      col=$((col + 1))
    done
    rm -f "$OUT_DIR/.p.tmp"
  fi
  if [ "$FAILURES" -gt 0 ]; then
    echo ""
    echo "## Failures by phase"
    echo ""
    sort "$FAILPHASE_FILE" | uniq -c | sed 's/^ */- /'
  fi
  echo ""
  echo "- Budget: p95 must sit within the 2–4 s ritual window (delivery-plan Phase 0 bar: 50 consecutive, 0 failures, p95 in window, replicated on a second Mac)."
  echo ""
  echo "Raw per-run logs and \`phases.tsv\` in this directory."
} > "$SUMMARY"

echo ""
cat "$SUMMARY"
