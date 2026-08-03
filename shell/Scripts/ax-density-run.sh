#!/bin/bash
# AX density spike driver — wraps the app-generic `axprobe` binary into the
# per-action protocol the coverage table needs (delivery-plan §15 Task 2, made
# app-agnostic): one short verbose probe window per canonical action, performed
# by hand 3x, logged per action, plus an ambient-noise baseline so signal can be
# told from chatter. Findings are distilled into docs/notes/, not left here.
#
# Usage:
#   shell/Scripts/ax-density-run.sh --bundle-id com.example.App --actions actions.txt \
#       [--seconds 20] [--baseline-seconds 30] [--out DIR]
#
# The actions file lists one action per line; blank lines and #-comments ignored.
set -euo pipefail

BUNDLE_ID=""
ACTIONS_FILE=""
SECONDS_PER_ACTION=20
BASELINE_SECONDS=30
OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --actions) ACTIONS_FILE="$2"; shift 2 ;;
    --seconds) SECONDS_PER_ACTION="$2"; shift 2 ;;
    --baseline-seconds) BASELINE_SECONDS="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$BUNDLE_ID" ] || { echo "--bundle-id required" >&2; exit 2; }
[ -n "$ACTIONS_FILE" ] && [ -f "$ACTIONS_FILE" ] || { echo "--actions FILE required and must exist" >&2; exit 2; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="$REPO_ROOT/shell/.build/debug/axprobe"

if [ -z "$OUT_DIR" ]; then
  SAFE_ID=$(echo "$BUNDLE_ID" | tr '.' '-')
  OUT_DIR="$REPO_ROOT/docs/notes/spike-ax-runs/$SAFE_ID-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT_DIR"

echo "== build =="
swift build --package-path "$REPO_ROOT/shell" --product axprobe >/dev/null

echo "== preflight: 2s probe (checks Accessibility grant + app running) =="
if ! "$BIN" --bundle-id "$BUNDLE_ID" --seconds 2 >/dev/null; then
  echo "preflight failed — see error above (grant Accessibility to this terminal; start the target app)" >&2
  exit 1
fi

# Read actions (bash-3.2-safe; no mapfile).
ACTIONS=()
while IFS= read -r line; do
  line="${line%%#*}"
  trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$trimmed" ] && ACTIONS+=("$trimmed")
done < "$ACTIONS_FILE"
N=${#ACTIONS[@]}
[ "$N" -gt 0 ] || { echo "no actions found in $ACTIONS_FILE" >&2; exit 2; }

echo ""
echo "Target: $BUNDLE_ID   Actions: $N   Window: ${SECONDS_PER_ACTION}s each   Out: $OUT_DIR"
echo ""
echo "== baseline: hands OFF the app for ${BASELINE_SECONDS}s (ambient notification noise) =="
read -r -p "Press Enter to start the baseline… " _
"$BIN" --bundle-id "$BUNDLE_ID" --seconds "$BASELINE_SECONDS" 2>&1 | tee "$OUT_DIR/00-baseline.log"

i=0
for action in "${ACTIONS[@]}"; do
  i=$((i + 1))
  slug=$(echo "$action" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g;s/^-//;s/-$//' | cut -c1-40)
  log=$(printf '%s/%02d-%s.log' "$OUT_DIR" "$i" "$slug")
  echo ""
  echo "== action $i/$N: $action =="
  echo "   Press Enter, switch to the app during the 3s countdown, then perform it 3x slowly."
  read -r -p "   Ready? " _
  for c in 3 2 1; do echo "   $c…"; sleep 1; done
  "$BIN" --bundle-id "$BUNDLE_ID" --seconds "$SECONDS_PER_ACTION" --verbose 2>&1 | tee "$log"
done

# Draft summary table from the per-action count sections; verdicts stay human.
SUMMARY="$OUT_DIR/summary.md"
{
  echo "# AX density run — $BUNDLE_ID — $(date '+%Y-%m-%d %H:%M')"
  echo ""
  echo "Window: ${SECONDS_PER_ACTION}s/action, performed 3x by hand. Baseline: ${BASELINE_SECONDS}s hands-off."
  echo ""
  echo "## Baseline (ambient noise)"
  echo ""
  echo '```'
  sed -n '/— notification counts —/,$p' "$OUT_DIR/00-baseline.log"
  echo '```'
  echo ""
  echo "## Per-action draft table"
  echo ""
  echo "Verdict scale: **Usable** (fires every rep, attributable, semantically distinct) / **Partial** (unreliable or ambiguous) / **Silent**."
  echo ""
  echo "| # | Action | Events | Rate (ev/s) | Top notifications | Verdict |"
  echo "|---|--------|--------|-------------|-------------------|---------|"
  i=0
  for action in "${ACTIONS[@]}"; do
    i=$((i + 1))
    slug=$(echo "$action" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g;s/^-//;s/-$//' | cut -c1-40)
    log=$(printf '%s/%02d-%s.log' "$OUT_DIR" "$i" "$slug")
    total=$(awk '/total:/ {print $2}' "$log" | tail -1)
    rate=$(awk '/rate:/ {print $4}' "$log" | tail -1)
    top=$(sed -n '/— notification counts —/,$p' "$log" | awk 'NR>1 && NF==2 {printf "%s×%s; ", $1, $2}' | head -c 120)
    echo "| $i | $action | ${total:-0} | ${rate:-0} | ${top:-—} | |"
  done
} > "$SUMMARY"

echo ""
echo "== done — draft table: $SUMMARY =="
echo "Fill the Verdict column (Usable/Partial/Silent), then distill into docs/notes/spike-ax-<app>-results.md."
