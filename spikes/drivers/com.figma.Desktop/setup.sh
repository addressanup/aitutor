#!/bin/bash
# Seed state for the Figma density run.
#
# ⚠️  READ THIS FIRST. The driver set types, drags, groups, deletes and undoes
#     against WHATEVER FIGMA DOCUMENT IS FRONTMOST. Point it at a throwaway file.
#     Pointing it at real work will edit real work. Undo is used heavily but is
#     not a guarantee, and Figma autosaves to the cloud.
#
# Figma cannot be seeded headlessly the way TextEdit can: it needs a signed-in
# account and an open design file, and its editing menus (Object, Text, Arrange,
# Vector) do not exist in the menu bar until one is open. That is a second
# unavoidable human step beyond the TCC checkbox — recorded honestly rather than
# worked around.
set -euo pipefail

BUNDLE_ID="com.figma.Desktop"
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROBE="$REPO_ROOT/shell/.build/debug/axprobe"

open -a Figma || { echo "Figma is not installed" >&2; exit 1; }
sleep 5

[ -x "$PROBE" ] || swift build --package-path "$REPO_ROOT/shell" --product axprobe >/dev/null

# The editing menus are the signal that a design file is actually open. Logged
# out, Figma shows only Apple/Figma/File/Edit/View/Window/Help.
MENUS=$("$PROBE" --bundle-id "$BUNDLE_ID" --dump-menu 2>/dev/null | awk '{print $1}' | sort -u)
echo "Top-level menus: $(echo "$MENUS" | tr '\n' ' ')"

if ! echo "$MENUS" | grep -qE '^(Object|Text|Arrange)$'; then
  cat >&2 <<'EOF'

  ✗ No design file is open (no Object/Text/Arrange menus).

    1. Sign in to Figma ("Log in with browser" on the start screen).
    2. Create a NEW, THROWAWAY design file — not one of your real ones.
    3. Leave that file frontmost, then re-run this script.

  The density run will edit that document.
EOF
  exit 1
fi

echo "✓ A design file is open and the editing menus are present."
echo "  Confirm it is a throwaway file before running:"
echo "    make spike-ax-run TARGET=$BUNDLE_ID DRIVERS=spikes/drivers/$BUNDLE_ID"
