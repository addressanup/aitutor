#!/bin/bash
# Seed state for the Keynote density run.
#
# ⚠️  READ THIS FIRST. The driver set inserts, drags, groups, deletes and undoes
#     against WHATEVER KEYNOTE DOCUMENT IS FRONTMOST, and it deletes slides. This
#     script creates a throwaway presentation at /tmp and then refuses to continue
#     unless THAT document is the one on screen. If the guard fails, fix the state
#     it describes; do not skip it.
#
# Keynote is the native-canvas control for the Obsidian (Electron) run: same
# protocol, same 20-action shape, an AppKit app instead of a browser one. The
# comparison is only worth anything if the two are driven the same way, so this
# script exists to make the starting state as reproducible as TextEdit's.
#
# Saving the document up front is load-bearing, not tidiness: an unsaved Keynote
# document makes cmd+s open an out-of-process save panel, which never receives
# pid-targeted input and would strand the run with a modal sheet on screen.
set -euo pipefail

BUNDLE_ID="com.apple.iWork.Keynote"
DOC="/tmp/aitutor-spike-keynote.key"
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROBE="$REPO_ROOT/shell/.build/debug/axprobe"
TREE="/tmp/aitutor-spike-keynote-tree.txt"

rm -rf "$DOC"

[ -x "$PROBE" ] || swift build --package-path "$REPO_ROOT/shell" --product axprobe >/dev/null

# ---- new blank presentation ------------------------------------------------
# Apple Events, not Accessibility: this needs an Automation grant for whatever
# terminal is running it (System Settings → Privacy & Security → Automation).
# That is a second one-time human step, recorded honestly rather than hidden.
if ! osascript <<EOF
tell application "Keynote"
  activate
  set spikeDoc to make new document
  save spikeDoc in POSIX file "$DOC"
end tell
EOF
then
  cat >&2 <<EOF

  ✗ Could not create the presentation with AppleScript.

    Usually this is a missing Automation grant: allow this terminal to control
    Keynote in System Settings → Privacy & Security → Automation, then re-run.

    Or do it by hand and re-run this script:
      1. Keynote → File → New, pick any theme.
      2. File → Save As…, save it to exactly:  $DOC
      3. Leave that document frontmost.

EOF
  exit 1
fi
sleep 3
echo "✓ Created throwaway presentation: $DOC"

# ---- guard 1: the editing menus are live -----------------------------------
MENUS=$("$PROBE" --bundle-id "$BUNDLE_ID" --dump-menu 2>/dev/null | sed -n 's/^  \([^ ]*\) > .*/\1/p' | sort -u)
echo "Top-level menus: $(echo "$MENUS" | tr '\n' ' ')"
for want in Insert Arrange Format Play; do
  if ! echo "$MENUS" | grep -qx "$want"; then
    echo "" >&2
    echo "  ✗ No '$want' menu — Keynote has no document open, or is still launching." >&2
    echo "    Open $DOC, leave it frontmost, then re-run this script." >&2
    exit 1
  fi
done

# ---- guard 2: it is OUR document, not somebody's deck ----------------------
"$PROBE" --bundle-id "$BUNDLE_ID" --dump-tree --depth 1 > "$TREE" 2>&1 || {
  echo "axprobe could not attach to $BUNDLE_ID — is this terminal granted Accessibility?" >&2
  exit 1
}
echo "Windows:"
sed -n 's/^  \(\[[0-9]*\].*\)$/    \1/p' "$TREE"

if ! grep -q "aitutor-spike-keynote" "$TREE"; then
  cat >&2 <<EOF

  ✗ The frontmost Keynote window is not the spike document.

    The window titles above do not mention "aitutor-spike-keynote", so some other
    presentation is in front — possibly real work. This driver set deletes slides.
    Refusing to continue.

    Bring $DOC to the front (Window menu), close or hide the others, then re-run.

EOF
  exit 1
fi

cat <<EOF

✓ Keynote is on the throwaway presentation and the editing menus are present.

  The canvas drivers use window-relative fractions and assume the default layout:
  slide navigator on the left, Format inspector on the right, one document window
  filling most of the screen. Widen the window before running; if the inspector is
  hidden the canvas shifts and the coordinates want re-checking against
  'axprobe --bundle-id $BUNDLE_ID --dump-tree'.

    make spike-ax-run TARGET=$BUNDLE_ID DRIVERS=spikes/drivers/$BUNDLE_ID ACTION_SECONDS=20
EOF
