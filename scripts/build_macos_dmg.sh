#!/usr/bin/env bash
#
# Build a macOS release DMG locally.
# Replaces the GitHub Actions workflow for cases where large assets
# (e.g. model.gguf) can't be pushed to the remote repository.
#
# Usage:
#   ./scripts/build_macos_dmg.sh [VERSION]
#
# Examples:
#   ./scripts/build_macos_dmg.sh           # uses version from pubspec.yaml
#   ./scripts/build_macos_dmg.sh v1.2.0    # explicit version tag

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# ---------------------------------------------------------------------------
# Resolve version
# ---------------------------------------------------------------------------
if [[ -n "${1:-}" ]]; then
  VERSION="$1"
else
  VERSION="v$(grep '^version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d+ -f1)"
fi

APP_NAME="Rewriter"
OUTPUT_DIR="$PROJECT_ROOT/dist"
mkdir -p "$OUTPUT_DIR"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
APP_PATH="build/macos/Build/Products/Release/Rewriter.app"

echo "==> Building $APP_NAME $VERSION"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if ! command -v flutter &>/dev/null; then
  echo "Error: flutter is not on PATH" >&2
  exit 1
fi

if [[ ! -f "assets/model.gguf" ]]; then
  echo "Warning: assets/model.gguf not found — the bundled model will be missing." >&2
fi

echo "==> Flutter doctor (summary)"
flutter doctor --verbose 2>&1 | head -20 || true

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo ""
echo "==> Getting dependencies"
flutter pub get

echo ""
echo "==> Building macOS release"
flutter build macos --release

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: $APP_PATH was not created. Build may have failed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Code-sign the app (ad-hoc) to clear any debug attributes
# ---------------------------------------------------------------------------
echo ""
echo "==> Code-signing the app bundle"
codesign --deep --force --sign - "$APP_PATH"
codesign --verify --verbose "$APP_PATH" || true

# ---------------------------------------------------------------------------
# Strip debug symbols from the main binary
# ---------------------------------------------------------------------------
MAIN_BINARY="$APP_PATH/Contents/MacOS/${APP_NAME}"
if [[ -f "$MAIN_BINARY" ]]; then
  echo "==> Stripping debug symbols"
  strip -x "$MAIN_BINARY" 2>/dev/null || true
  codesign --deep --force --sign - "$APP_PATH"
fi

# ---------------------------------------------------------------------------
# Package DMG with drag-to-Applications layout
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating DMG: $DMG_PATH"

rm -f "$DMG_PATH"
DMG_RW="$OUTPUT_DIR/${DMG_NAME%.dmg}-rw.dmg"
rm -f "$DMG_RW"

DMG_SIZE_KB=$(du -sk "$APP_PATH" | cut -f1)
DMG_SIZE_MB=$(( (DMG_SIZE_KB / 1024) * 120 / 100 + 50 ))

hdiutil create \
  -volname "$APP_NAME" \
  -size "${DMG_SIZE_MB}m" \
  -fs HFS+ \
  -ov \
  -type UDIF \
  -layout NONE \
  "$DMG_RW"

MOUNT_DIR="$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" \
  | grep '/Volumes/' | tail -1 | awk -F'\t' '{print $NF}')"

if [[ -n "$MOUNT_DIR" ]]; then
  cp -R "$APP_PATH" "$MOUNT_DIR/"

  osascript <<APPLESCRIPT
tell application "Finder"
  make new alias file at POSIX file "$MOUNT_DIR" to POSIX file "/Applications" with properties {name:"Applications"}
end tell
APPLESCRIPT

  osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 640, 400}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set position of item "${APP_NAME}.app" of container window to {130, 150}
    set position of item "Applications" of container window to {410, 150}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

  sync
  hdiutil detach "$MOUNT_DIR" -quiet
fi

hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$DMG_RW"

DMG_SIZE="$(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "==> Done! DMG created:"
echo "    $DMG_PATH  ($DMG_SIZE)"
