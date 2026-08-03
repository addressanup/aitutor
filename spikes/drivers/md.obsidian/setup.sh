#!/bin/bash
# Seed state for the Obsidian (Electron/Chromium) density run.
#
# ⚠️  READ THIS FIRST. The driver set types, formats, cuts, deletes and undoes
#     against WHATEVER NOTE IS FRONTMOST in whatever vault Obsidian has open.
#     This script creates a THROWAWAY vault under /tmp and then refuses to go
#     any further unless Obsidian is actually showing that vault — so a real
#     vault cannot be edited by accident. If the guard fails, fix the state it
#     describes; do not skip it.
#
# Obsidian is the architecturally interesting target: it is browser-backed, so
# this run answers whether Chromium exposes AX a tutor can observe. Two things
# follow from that and are handled below:
#   1. Chromium builds its accessibility tree lazily, only once an assistive
#      client asks. Probing without AXManualAccessibility reports near-silence —
#      a false Silent verdict for all 20 actions rather than a measurement of the
#      app. This script sets it once on the running process; it stays on for that
#      process's lifetime, so the harness run afterwards sees a real tree.
#      If Obsidian is quit and relaunched, re-run this script.
#   2. Opening a vault is a first-run flow with no scriptable entry point. We try,
#      then verify, then print exact instructions and fail rather than guess.
set -euo pipefail

BUNDLE_ID="md.obsidian"
VAULT="/tmp/aitutor-spike-vault"
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROBE="$REPO_ROOT/shell/.build/debug/axprobe"
TREE="/tmp/aitutor-spike-obsidian-tree.txt"

# ---- throwaway vault -------------------------------------------------------
# Seeded fresh every run: the drivers leave the notes in an arbitrary state and
# the next run must start from a known one.
mkdir -p "$VAULT"
cat > "$VAULT/Scratch.md" <<'EOF'
Scratch note for the AX density spike.

The driver set types into this note, formats it, links from it, searches it and
undoes most of what it did. Nothing here is worth keeping.
EOF
cat > "$VAULT/Note B.md" <<'EOF'
Note B exists so the link suggester and the quick switcher have somewhere to go.
EOF
cat > "$VAULT/Note C.md" <<'EOF'
Note C is the third switch target, and gives global search more than one hit.
EOF
echo "✓ Seeded throwaway vault: $VAULT"

[ -x "$PROBE" ] || swift build --package-path "$REPO_ROOT/shell" --product axprobe >/dev/null

# ---- open it ---------------------------------------------------------------
# `open -a` with a folder is the only non-AppleScript path, and Obsidian only
# honours it for a vault it already knows. Whether it worked is decided below by
# looking at the window title, not by this command's exit status.
open -a Obsidian "$VAULT" 2>/dev/null || open -a Obsidian || {
  echo "Obsidian is not installed (no app named Obsidian)" >&2
  exit 1
}
sleep 6

# ---- turn Chromium's AX tree on, and read the window titles ----------------
"$PROBE" --bundle-id "$BUNDLE_ID" --enable-ax --dump-tree --depth 1 > "$TREE" 2>&1 || {
  echo "axprobe could not attach to $BUNDLE_ID — is Obsidian running, and is this terminal granted Accessibility?" >&2
  exit 1
}
grep -q "AXManualAccessibility set: yes" "$TREE" \
  && echo "✓ AXManualAccessibility set — Chromium will build an AX tree." \
  || echo "! AXManualAccessibility was not accepted (already on, or this build ignores it) — check the density numbers are not all zero."

echo "Windows:"
sed -n 's/^  \(\[[0-9]*\].*\)$/    \1/p' "$TREE"

# ---- guard 1: a real menu bar (the app is up, not mid-launch) --------------
MENUS=$("$PROBE" --bundle-id "$BUNDLE_ID" --dump-menu 2>/dev/null | sed -n 's/^  \([^ ]*\) > .*/\1/p' | sort -u)
echo "Top-level menus: $(echo "$MENUS" | tr '\n' ' ')"
for want in File Edit View; do
  if ! echo "$MENUS" | grep -qx "$want"; then
    echo "" >&2
    echo "  ✗ No '$want' menu — Obsidian is still launching, or is showing a chrome-less window." >&2
    echo "    Wait for the main window, then re-run this script." >&2
    exit 1
  fi
done

# ---- guard 2: it is OUR vault, not a real one ------------------------------
# Obsidian titles its window "<note> - <vault> - Obsidian v1.x". The vault name
# is the only thing standing between this run and somebody's real notes.
if ! grep -q "aitutor-spike-vault" "$TREE"; then
  cat >&2 <<EOF

  ✗ Obsidian is not showing the throwaway vault.

    The window titles above do not mention "aitutor-spike-vault", which means
    Obsidian is on some other vault — possibly a real one. Refusing to continue.

    Open the spike vault by hand (Obsidian cannot be scripted into a vault it
    has never seen):

      1. Obsidian → File → Open vault…  (or the vault switcher, bottom-left)
      2. "Open folder as vault", choose:  $VAULT
      3. Dismiss any first-run or changelog dialog.
      4. Open the note "Scratch" and click once in the editor.
      5. Re-run this script.

EOF
  exit 1
fi

cat <<EOF

✓ Obsidian is on the throwaway vault and the menu bar is live.

  Before running: open the note "Scratch" and click once in its editor body.
  The first driver clicks into the editor itself, but a note has to be open.

  Then:
    make spike-ax-run TARGET=$BUNDLE_ID DRIVERS=spikes/drivers/$BUNDLE_ID ACTION_SECONDS=20
EOF
