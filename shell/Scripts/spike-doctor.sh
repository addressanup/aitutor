#!/bin/bash
# Spike preflight doctor — everything a second Mac needs before it can reproduce
# the Phase 0 spike protocols (delivery-plan §5 Phase 0: the snapshot bar requires
# the run be "replicated on a second Mac before the review"). App-agnostic: the
# target is a bundle id, never a hardcoded app.
#
# It checks and reports rather than fixing, one ✓/✗ per line with an actionable
# fix under every failure, and exits non-zero if anything essential is missing.
# The subtle check is Accessibility: CLI tools inherit the TCC identity of the
# terminal app hosting them (README "The TCC dev loop"), so the grant belongs to
# Terminal/iTerm/VS Code — not to axprobe, and not to this script.
#
# Usage:
#   spike-doctor.sh --bundle-id com.example.App [--rebuild]
#
# Operator walkthrough: docs/notes/replication.md
set -euo pipefail

BUNDLE_ID=""
REBUILD=0

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --rebuild) REBUILD=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$BUNDLE_ID" ] || { echo "--bundle-id required (e.g. --bundle-id com.apple.TextEdit)" >&2; exit 2; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/shell/.build/debug"
PROBE="$BUILD_DIR/axprobe"

OK=0; BAD=0; WARN=0

ok()   { printf '  ✓ %-24s %s\n' "$1" "${2:-}"; OK=$((OK + 1)); }
bad()  { printf '  ✗ %-24s %s\n' "$1" "${2:-}"; BAD=$((BAD + 1)); }
warn() { printf '  ⚠ %-24s %s\n' "$1" "${2:-}"; WARN=$((WARN + 1)); }
fix()  { printf '      → %s\n' "$1"; }

# True when $1 >= $2 as dotted versions. bash-3.2-safe, no arithmetic on strings.
ver_ge() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]; }

# The .app bundle of the terminal hosting this shell — the process that actually
# holds (or lacks) the Accessibility grant. Walks the parent chain because the
# immediate parent is make/zsh, not the terminal.
host_terminal_app() {
  local pid="$PPID" exe i=0
  while [ "$pid" -gt 1 ] && [ "$i" -lt 12 ]; do
    exe=$(ps -o comm= -p "$pid" 2>/dev/null || true)
    case "$exe" in
      */*.app/Contents/MacOS/*) echo "${exe%%.app/Contents/MacOS/*}.app"; return 0 ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -n "$pid" ] || return 1
    i=$((i + 1))
  done
  return 1
}

TERMINAL_APP=$(host_terminal_app || true)
TERMINAL_NAME=${TERM_PROGRAM:-$(basename "${TERMINAL_APP:-unknown}" .app)}
HEAD_SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "not-a-git-checkout")

echo "== spike-doctor =="
echo "Repo:     $REPO_ROOT ($HEAD_SHA)"
echo "Target:   $BUNDLE_ID"
echo "Terminal: $TERMINAL_NAME ${TERMINAL_APP:+($TERMINAL_APP)}"
echo ""

# ---------------------------------------------------------------- repo state --
echo "-- repo --"

MISSING_MARKERS=""
for marker in Makefile shell/Package.swift protocol core; do
  [ -e "$REPO_ROOT/$marker" ] || MISSING_MARKERS="$MISSING_MARKERS $marker"
done
if [ -z "$MISSING_MARKERS" ]; then
  ok "repo layout" "Makefile, shell/, protocol/, core/ present"
else
  bad "repo layout" "missing:$MISSING_MARKERS"
  fix "this script must live in a full checkout at shell/Scripts/ — re-clone the repo"
fi

case "$PWD/" in
  "$REPO_ROOT"/*) ok "working directory" "$PWD" ;;
  *) warn "working directory" "$PWD is outside the repo"
     fix "the make targets assume the repo root: cd $REPO_ROOT" ;;
esac

SWIFT_FLOOR=$(sed -n 's|^// *swift-tools-version: *\([0-9][0-9.]*\).*|\1|p' "$REPO_ROOT/shell/Package.swift" 2>/dev/null | head -1)
SWIFT_FLOOR=${SWIFT_FLOOR:-6.2}
if command -v swift >/dev/null 2>&1; then
  SWIFT_VER=$(swift --version 2>&1 | sed -n 's/.*Apple Swift version \([0-9][0-9.]*\).*/\1/p' | head -1)
  if [ -z "$SWIFT_VER" ]; then
    warn "swift" "present, version unparseable (floor $SWIFT_FLOOR)"
    fix "check by hand: swift --version"
  elif ver_ge "$SWIFT_VER" "$SWIFT_FLOOR"; then
    ok "swift $SWIFT_VER" "floor $SWIFT_FLOOR (shell/Package.swift)"
  else
    bad "swift $SWIFT_VER" "below the $SWIFT_FLOOR floor in shell/Package.swift"
    fix "install a current Xcode, then: sudo xcode-select -s /Applications/Xcode.app"
    fix "Command Line Tools alone can ship an older Swift than Xcode does"
  fi
else
  bad "swift" "not on PATH"
  fix "install Xcode from the App Store, launch it once, then: xcode-select --install"
fi

NODE_FLOOR=$(sed -n 's/.*"node"[[:space:]]*:[[:space:]]*">=[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$REPO_ROOT/package.json" 2>/dev/null | head -1)
NODE_FLOOR=${NODE_FLOOR:-26}
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node --version 2>/dev/null | sed 's/^v//')
  if ver_ge "$NODE_VER" "$NODE_FLOOR"; then
    ok "node $NODE_VER" "floor $NODE_FLOOR (package.json engines)"
  else
    bad "node $NODE_VER" "below the $NODE_FLOOR floor in package.json"
    fix "install Node $NODE_FLOOR+ (nodejs.org, or: brew install node)"
  fi
else
  bad "node" "not on PATH — the density verdict tool is Node"
  fix "install Node $NODE_FLOOR+ (nodejs.org, or: brew install node)"
fi

if command -v pnpm >/dev/null 2>&1; then
  ok "pnpm $(pnpm --version 2>/dev/null)" "needed for 'make check', not for the spikes"
else
  warn "pnpm" "not on PATH"
  fix "corepack enable (ships with Node), then: make bootstrap"
fi

# ----------------------------------------------------------- spike binaries --
echo ""
echo "-- spike binaries --"

for product in axprobe snapshot-spike axdrive; do
  binary="$BUILD_DIR/$product"
  if [ "$REBUILD" -eq 0 ] && [ -x "$binary" ]; then
    ok "$product" "present in shell/.build/debug/"
    continue
  fi
  if swift build --package-path "$REPO_ROOT/shell" --product "$product" >/dev/null 2>&1; then
    ok "$product" "built"
  else
    bad "$product" "build failed"
    fix "see the compiler output: swift build --package-path shell --product $product"
  fi
done

# ------------------------------------------------------- accessibility (TCC) --
echo ""
echo "-- accessibility (TCC) --"

# axprobe checks AXIsProcessTrusted() before it resolves the bundle id, so probing
# a deliberately absent app separates the two failures without needing any app
# running: "App not running" proves the grant, "Accessibility not granted" denies it.
TCC_SENTINEL="com.aitutor.spike-doctor.no-such-app"
if [ ! -x "$PROBE" ]; then
  bad "grant to this terminal" "cannot test — axprobe is not built"
  fix "fix the build failure above, then re-run spike-doctor"
else
  set +e
  TCC_OUT=$("$PROBE" --bundle-id "$TCC_SENTINEL" --seconds 1 2>&1)
  set -e
  case "$TCC_OUT" in
    *"App not running"*)
      ok "grant to this terminal" "$TERMINAL_NAME is trusted"
      ;;
    *"Accessibility not granted"*)
      bad "grant to this terminal" "$TERMINAL_NAME is NOT trusted"
      fix "System Settings → Privacy & Security → Accessibility → [ + ]"
      fix "add ${TERMINAL_APP:-your terminal app} and switch its toggle ON"
      fix "then QUIT AND REOPEN the terminal — the grant is read at process start"
      fix "the grant belongs to the TERMINAL APP, not to axprobe: CLI tools inherit"
      fix "their host's TCC identity, so switching to iTerm / VS Code / Ghostty means"
      fix "granting that app too (README: 'The TCC dev loop')"
      ;;
    *)
      bad "grant to this terminal" "unrecognized axprobe response"
      fix "run it directly and read the error: shell/.build/debug/axprobe --bundle-id $TCC_SENTINEL --seconds 1"
      ;;
  esac
fi

# ------------------------------------------------------------- target app --
echo ""
echo "-- target app: $BUNDLE_ID --"

APP_PATH=$(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
  APP_PATH=$(osascript -e "POSIX path of (path to application id \"$BUNDLE_ID\")" 2>/dev/null || true)
  APP_PATH=${APP_PATH%/}
fi
if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
  ok "installed" "$APP_PATH"
else
  bad "installed" "no app with bundle id $BUNDLE_ID"
  fix "check the id against what is installed: mdls -name kMDItemCFBundleIdentifier /Applications/<App>.app"
  fix "bundle ids are case-sensitive here (com.apple.TextEdit, not com.apple.textedit)"
fi

if [ -n "$(lsappinfo find "bundleid=$BUNDLE_ID" 2>/dev/null)" ]; then
  ok "running" "both protocols observe a live process"
else
  bad "running" "not running"
  fix "launch it: open -b $BUNDLE_ID"
  fix "open the document/project the driver set expects (see spikes/drivers/$BUNDLE_ID/)"
fi

# ---------------------------------------------------------------- verdict --
echo ""
if [ "$BAD" -eq 0 ]; then
  echo "== $OK ok, $WARN warning(s) — ready to replicate =="
  echo "  make spike-ax-run TARGET=$BUNDLE_ID DRIVERS=spikes/drivers/$BUNDLE_ID"
  echo "  make spike-snapshot-run TARGET=$BUNDLE_ID MENU=\"File>…\" RUNS=50"
  echo "  protocol + what to send back: docs/notes/replication.md"
else
  echo "== $OK ok, $BAD blocking, $WARN warning(s) — fix the ✗ lines above =="
  exit 1
fi
