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
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_PATH="build/macos/Build/Products/Release/rewriter.app"

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
# Package DMG
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating DMG: $DMG_NAME"

DMG_STAGE="$(mktemp -d)"
cp -R "$APP_PATH" "$DMG_STAGE/"

# Remove old DMG if present
rm -f "$DMG_NAME"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_NAME"

rm -rf "$DMG_STAGE"

DMG_SIZE="$(du -h "$DMG_NAME" | cut -f1)"
echo ""
echo "==> Done! DMG created:"
echo "    $PROJECT_ROOT/$DMG_NAME  ($DMG_SIZE)"
