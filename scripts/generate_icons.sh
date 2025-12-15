#!/bin/bash

# Script to generate macOS app icon sizes from assets/icon.png
# Uses macOS built-in 'sips' tool (no external dependencies required)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ICON_SOURCE="$PROJECT_ROOT/assets/icon.png"
ICON_OUTPUT_DIR="$PROJECT_ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"

# Check if source icon exists
if [ ! -f "$ICON_SOURCE" ]; then
    echo "Error: Source icon not found at $ICON_SOURCE"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$ICON_OUTPUT_DIR"

echo "Generating macOS app icons from $ICON_SOURCE..."
echo "Using macOS built-in 'sips' tool..."

# Generate all required icon sizes using sips
# 16x16 (1x)
sips -z 16 16 "$ICON_SOURCE" --out "$ICON_OUTPUT_DIR/app_icon_16.png" > /dev/null 2>&1

# 16x16 (2x) = 32x32
sips -z 32 32 "$ICON_SOURCE" --out "$ICON_OUTPUT_DIR/app_icon_32.png" > /dev/null 2>&1

# 32x32 (2x) = 64x64
sips -z 64 64 "$ICON_SOURCE" --out "$ICON_OUTPUT_DIR/app_icon_64.png" > /dev/null 2>&1

# 128x128 (1x)
sips -z 128 128 "$ICON_SOURCE" --out "$ICON_OUTPUT_DIR/app_icon_128.png" > /dev/null 2>&1

# 128x128 (2x) = 256x256
sips -z 256 256 "$ICON_SOURCE" --out "$ICON_OUTPUT_DIR/app_icon_256.png" > /dev/null 2>&1

# 256x256 (2x) = 512x512
sips -z 512 512 "$ICON_SOURCE" --out "$ICON_OUTPUT_DIR/app_icon_512.png" > /dev/null 2>&1

# 512x512 (2x) = 1024x1024
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICON_OUTPUT_DIR/app_icon_1024.png" > /dev/null 2>&1

echo "✓ Successfully generated all macOS app icon sizes!"
echo "Icons saved to: $ICON_OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Rebuild the macOS app to see the new icon"
echo "2. The icon will be used for:"
echo "   - App icon in Finder and Dock"
echo "   - System tray icon (via TrayManager)"
echo "   - Notification icon (via NotificationService)"
