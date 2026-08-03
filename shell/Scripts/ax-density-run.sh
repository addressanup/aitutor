#!/bin/bash
# AX density spike driver — wraps the app-generic `axprobe` binary into the
# per-action protocol the coverage table needs (delivery-plan §15 Task 2, made
# app-agnostic): one probe window per canonical action, logged per action, plus
# an ambient-noise baseline so signal can be told from chatter. Findings are
# distilled into docs/notes/, not left here.
#
# Two modes:
#   Interactive (human performs each action 3x):
#     ax-density-run.sh --bundle-id com.example.App --actions actions.txt
#   Headless (axdrive performs each action from a driver script):
#     ax-density-run.sh --bundle-id com.example.App --drivers spikes/drivers/<app>/
#
# Actions file: one action per line; blank lines and #-comments ignored.
# Drivers dir: NN-*.axd files (axdrive DSL), sorted order; first "# name: X"
# line names the action, filename otherwise.
#
# --repeat N runs the whole protocol N times into <out>/run-1 … <out>/run-N and
# aggregates them. A single run of this protocol is not evidence at the bar boundary:
# two identical runs ninety minutes apart scored 20/20 and 17/20, with individual
# actions swinging from 67 events to 2. The bar belongs on a median, not on one run.
set -euo pipefail

BUNDLE_ID=""
ACTIONS_FILE=""
DRIVERS_DIR=""
SECONDS_PER_ACTION=20
BASELINE_SECONDS=30
OUT_DIR=""
REPEAT=1

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --actions) ACTIONS_FILE="$2"; shift 2 ;;
    --drivers) DRIVERS_DIR="$2"; shift 2 ;;
    --seconds) SECONDS_PER_ACTION="$2"; shift 2 ;;
    --baseline-seconds) BASELINE_SECONDS="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --repeat) REPEAT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$BUNDLE_ID" ] || { echo "--bundle-id required" >&2; exit 2; }
case "$REPEAT" in
  ''|*[!0-9]*) echo "--repeat must be a positive integer" >&2; exit 2 ;;
esac
[ "$REPEAT" -ge 1 ] || { echo "--repeat must be >= 1" >&2; exit 2; }
if [ -n "$DRIVERS_DIR" ]; then
  [ -d "$DRIVERS_DIR" ] || { echo "--drivers DIR must exist" >&2; exit 2; }
elif [ -n "$ACTIONS_FILE" ]; then
  [ -f "$ACTIONS_FILE" ] || { echo "--actions FILE must exist" >&2; exit 2; }
else
  echo "one of --actions FILE (interactive) or --drivers DIR (headless) required" >&2; exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROBE="$REPO_ROOT/shell/.build/debug/axprobe"
DRIVE="$REPO_ROOT/shell/.build/debug/axdrive"

if [ -z "$OUT_DIR" ]; then
  SAFE_ID=$(echo "$BUNDLE_ID" | tr '.' '-')
  OUT_DIR="$REPO_ROOT/docs/notes/spike-ax-runs/$SAFE_ID-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT_DIR"

echo "== build =="
swift build --package-path "$REPO_ROOT/shell" --product axprobe >/dev/null
[ -z "$DRIVERS_DIR" ] || swift build --package-path "$REPO_ROOT/shell" --product axdrive >/dev/null

echo "== preflight: 2s probe (checks Accessibility grant + app running) =="
if ! "$PROBE" --bundle-id "$BUNDLE_ID" --seconds 2 >/dev/null; then
  echo "preflight failed — see error above (grant Accessibility to this terminal; start the target app)" >&2
  exit 1
fi

# Assemble the action list: names + (headless) driver files. bash-3.2-safe.
ACTIONS=()
DRIVER_FILES=()
if [ -n "$DRIVERS_DIR" ]; then
  for f in "$DRIVERS_DIR"/*.axd; do
    [ -e "$f" ] || { echo "no .axd driver files in $DRIVERS_DIR" >&2; exit 2; }
    name=$(sed -n 's/^# name:[[:space:]]*//p' "$f" | head -1)
    [ -n "$name" ] || name=$(basename "$f" .axd)
    ACTIONS+=("$name")
    DRIVER_FILES+=("$f")
  done
else
  while IFS= read -r line; do
    line="${line%%#*}"
    trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$trimmed" ] && ACTIONS+=("$trimmed")
  done < "$ACTIONS_FILE"
fi
N=${#ACTIONS[@]}
[ "$N" -gt 0 ] || { echo "no actions found" >&2; exit 2; }

echo ""
echo "Target: $BUNDLE_ID   Actions: $N   Window: ${SECONDS_PER_ACTION}s each   Out: $OUT_DIR"
echo "Mode: $([ -n "$DRIVERS_DIR" ] && echo headless || echo interactive)   Repeats: $REPEAT"

# One pass of the whole protocol into $1. Called once per repeat, so every run is an
# independent measurement — including its own baseline, since ambient noise is exactly
# the thing that drifts between runs and reusing one baseline would hide that drift.
run_protocol() {
  local out="$1"
  mkdir -p "$out"

  echo ""
  echo "== baseline: ${BASELINE_SECONDS}s ambient notification noise (hands off) =="
  if [ -z "$DRIVERS_DIR" ]; then read -r -p "Press Enter to start the baseline… " _; fi
  "$PROBE" --bundle-id "$BUNDLE_ID" --seconds "$BASELINE_SECONDS" 2>&1 | tee "$out/00-baseline.log"

  local i=0 action slug log driver probe_pid c
  for action in "${ACTIONS[@]}"; do
    i=$((i + 1))
    slug=$(echo "$action" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g;s/^-//;s/-$//' | cut -c1-40)
    log=$(printf '%s/%02d-%s.log' "$out" "$i" "$slug")
    echo ""
    echo "== action $i/$N: $action =="
    if [ -n "$DRIVERS_DIR" ]; then
      driver="${DRIVER_FILES[$((i - 1))]}"
      "$PROBE" --bundle-id "$BUNDLE_ID" --seconds "$SECONDS_PER_ACTION" --verbose > "$log" 2>&1 &
      probe_pid=$!
      sleep 1
      if ! "$DRIVE" --bundle-id "$BUNDLE_ID" --script "$driver" >> "$log" 2>&1; then
        echo "DRIVER-ERROR: $driver" | tee -a "$log"
      fi
      wait "$probe_pid"
      tail -n +1 "$log" | sed -n '/— notification counts —/,$p' | sed 's/^/   /'
    else
      echo "   Press Enter, switch to the app during the 3s countdown, then perform it 3x slowly."
      read -r -p "   Ready? " _
      for c in 3 2 1; do echo "   $c…"; sleep 1; done
      "$PROBE" --bundle-id "$BUNDLE_ID" --seconds "$SECONDS_PER_ACTION" --verbose 2>&1 | tee "$log"
    fi
  done

  # Draft summary table from the per-action count sections; verdicts stay human.
  {
    echo "# AX density run — $BUNDLE_ID — $(date '+%Y-%m-%d %H:%M')"
    echo ""
    echo "Mode: $([ -n "$DRIVERS_DIR" ] && echo "headless (axdrive)" || echo "interactive (human, 3x/action)")."
    echo "Window: ${SECONDS_PER_ACTION}s/action. Baseline: ${BASELINE_SECONDS}s hands-off."
    echo ""
    echo "## Baseline (ambient noise)"
    echo ""
    echo '```'
    sed -n '/— notification counts —/,$p' "$out/00-baseline.log"
    echo '```'
    echo ""
    echo "## Per-action table"
    echo ""
    echo "Verdict scale: **Usable** (fires every rep, attributable above ambient, semantically distinct) / **Partial** (unreliable or ambiguous) / **Silent**."
    echo "Verdicts are computed by \`shell/Scripts/ax-density-verdict.mjs\` from these logs — rerun it on this directory to reproduce them."
    echo ""
    node "$REPO_ROOT/shell/Scripts/ax-density-verdict.mjs" "$out" \
      ${DRIVERS_DIR:+--drivers "$DRIVERS_DIR"} 2>/dev/null \
      || echo "_(verdict tool failed — inspect the raw logs)_"
    echo ""
    echo "## Driver errors"
    echo ""
    if grep -lq "DRIVER-ERROR" "$out"/*.log 2>/dev/null; then
      grep -h "DRIVER-ERROR" "$out"/*.log | sed 's/^/- /'
    else
      echo "None."
    fi
  } > "$out/summary.md"
}

# --repeat 1 writes straight into $OUT_DIR, so existing runs and every path recorded in
# docs/ keep their shape; only repeated runs get the run-N nesting.
RUN_DIRS=()
r=0
while [ "$r" -lt "$REPEAT" ]; do
  r=$((r + 1))
  if [ "$REPEAT" -eq 1 ]; then
    RUN_DIR="$OUT_DIR"
  else
    RUN_DIR="$OUT_DIR/run-$r"
    echo ""
    echo "######## repeat $r/$REPEAT ########"
  fi
  run_protocol "$RUN_DIR"
  RUN_DIRS+=("$RUN_DIR")
done

echo ""
if [ "$REPEAT" -eq 1 ]; then
  echo "== done — scored table: $OUT_DIR/summary.md =="
  node "$REPO_ROOT/shell/Scripts/ax-density-verdict.mjs" "$OUT_DIR" ${DRIVERS_DIR:+--drivers "$DRIVERS_DIR"} 2>/dev/null | tail -3
  echo "A single run cannot settle a bar-boundary score — rerun with --repeat 3 before deciding."
else
  AGGREGATE="$OUT_DIR/aggregate.md"
  DETAIL=""
  for d in "${RUN_DIRS[@]}"; do DETAIL="$DETAIL \`$(basename "$d")/summary.md\`"; done
  {
    echo "# AX density — $REPEAT repeated runs — $BUNDLE_ID — $(date '+%Y-%m-%d %H:%M')"
    echo ""
    echo "Per-run detail:$DETAIL"
    echo ""
  } > "$AGGREGATE"
  # The aggregator exits non-zero on anything short of PASS; that is a verdict, not a
  # tool failure, so it must not abort the write. A missing VERDICT line is the only
  # thing that distinguishes the two.
  node "$REPO_ROOT/shell/Scripts/ax-density-verdict.mjs" "${RUN_DIRS[@]}" \
    ${DRIVERS_DIR:+--drivers "$DRIVERS_DIR"} >> "$AGGREGATE" 2>/dev/null || true
  grep -q "VERDICT:" "$AGGREGATE" || echo "_(aggregator failed — inspect the per-run summaries)_" >> "$AGGREGATE"
  echo "== done — $REPEAT runs aggregated: $AGGREGATE =="
  sed -n '/VERDICT:/,$p' "$AGGREGATE"
fi
echo "Distill into docs/notes/spike-ax-<app>-results.md."
