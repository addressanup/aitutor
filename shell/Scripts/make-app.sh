#!/usr/bin/env bash
# Assemble build/Tutor.app from the SwiftPM executable and sign it. Signing with a
# STABLE identity (default: the self-signed "TutorShell Dev" cert; `make cert`) keeps
# TCC grants alive across rebuilds — ad-hoc signing changes the CDHash and silently
# invalidates Accessibility/Input Monitoring grants.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${CONFIG:-debug}"
APP="build/Tutor.app"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
SIGN_ID="${SIGN_ID:-TutorShell Dev}"

swift build -c "$CONFIG" --product Tutor >/dev/null

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Tutor" "$APP/Contents/MacOS/Tutor"
cp Config/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
  codesign --force --entitlements Config/dev.entitlements \
    --identifier com.aitutor.shell --sign "$SIGN_ID" "$APP"
  echo "signed $APP with '$SIGN_ID' (TCC grants persist across rebuilds)"
else
  echo "WARNING: signing identity '$SIGN_ID' not found — falling back to ad-hoc." >&2
  echo "         TCC grants will NOT survive rebuilds. Run 'make cert' to fix." >&2
  codesign --force --entitlements Config/dev.entitlements \
    --identifier com.aitutor.shell --sign - "$APP"
fi

echo "built $APP"
