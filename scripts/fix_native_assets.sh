#!/bin/bash

# Script to manually download and install MediaPipe GenAI native libraries
# This is a workaround for Flutter's native-assets not automatically executing build.dart

set -e

echo "=========================================="
echo "Fixing Native Assets - MediaPipe GenAI"
echo "=========================================="
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"
echo ""

# Detect platform
PLATFORM="macos"
ARCH="arm64"
TARGET_OS="macos"

if [[ "$(uname -m)" == "x86_64" ]]; then
    ARCH="x64"
fi

echo "Platform: $PLATFORM ($ARCH)"
echo ""

# URL for macOS ARM64 native library
DOWNLOAD_URL="https://storage.googleapis.com/mediapipe-nightly-public/prod/mediapipe/macos_flutter/release/61/20240508-094837/darwin_arm64/libllm_inference_engine.dylib"

# Create native assets directory structure
NATIVE_ASSETS_DIR="build/native_assets/$PLATFORM/$ARCH"
mkdir -p "$NATIVE_ASSETS_DIR"

echo "Step 1: Downloading native library..."
echo "   URL: $DOWNLOAD_URL"
echo "   Destination: $NATIVE_ASSETS_DIR/libllm_inference_engine.dylib"
echo ""

# Download the library
if curl -f -L -o "$NATIVE_ASSETS_DIR/libllm_inference_engine.dylib" "$DOWNLOAD_URL" 2>&1; then
    echo "✅ Native library downloaded successfully"
    
    # Check file size
    FILE_SIZE=$(stat -f%z "$NATIVE_ASSETS_DIR/libllm_inference_engine.dylib" 2>/dev/null || stat -c%s "$NATIVE_ASSETS_DIR/libllm_inference_engine.dylib" 2>/dev/null || echo "0")
    echo "   File size: $FILE_SIZE bytes"
else
    echo "❌ Failed to download native library"
    echo "   This may be due to:"
    echo "   - Network connectivity issues"
    echo "   - URL no longer available"
    echo "   - Permission issues"
    exit 1
fi
echo ""

# Update native_assets.json
echo "Step 2: Updating native_assets.json..."
NATIVE_ASSETS_JSON=".dart_tool/flutter_build/*/native_assets.json"
if ls $NATIVE_ASSETS_JSON 1> /dev/null 2>&1; then
    NATIVE_ASSETS_FILE=$(ls $NATIVE_ASSETS_JSON | head -1)
    echo "   Found: $NATIVE_ASSETS_FILE"
    
    # Create a backup
    cp "$NATIVE_ASSETS_FILE" "${NATIVE_ASSETS_FILE}.backup"
    
    # Update JSON (simple approach - add entry)
    echo "   Note: native_assets.json will be regenerated on next build"
else
    echo "   ⚠️  native_assets.json not found (will be created on next build)"
fi
echo ""

# Copy to app bundle (for macOS) - try multiple possible locations
echo "Step 3: Copying library to app bundle..."
APP_BUNDLE_DEBUG="build/macos/Build/Products/Debug/rewriter.app/Contents/MacOS"
APP_BUNDLE_PROFILE="build/macos/Build/Products/Profile/rewriter.app/Contents/MacOS"
APP_BUNDLE_RELEASE="build/macos/Build/Products/Release/rewriter.app/Contents/MacOS"

COPIED=0
for APP_BUNDLE in "$APP_BUNDLE_DEBUG" "$APP_BUNDLE_PROFILE" "$APP_BUNDLE_RELEASE"; do
    if [ -d "$APP_BUNDLE" ]; then
        cp "$NATIVE_ASSETS_DIR/libllm_inference_engine.dylib" "$APP_BUNDLE/"
        echo "✅ Library copied to: $APP_BUNDLE"
        COPIED=1
    fi
done

if [ $COPIED -eq 0 ]; then
    echo "   ⚠️  App bundle not found (will be copied during build)"
    echo "   Run this script again after building: flutter build macos --debug"
fi
echo ""

# Update native_assets.json files
echo "Step 4: Updating native_assets.json..."
if [ -f "scripts/update_native_assets_json.sh" ]; then
    ./scripts/update_native_assets_json.sh
else
    echo "   ⚠️  update_native_assets_json.sh not found, skipping JSON update"
fi
echo ""

echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Rebuild the app:"
echo "   flutter build macos --debug"
echo ""
echo "2. Copy library to app bundle:"
echo "   ./scripts/copy_native_libs.sh"
echo ""
echo "3. Or run the app (will auto-copy):"
echo "   flutter run -d macos"
echo ""
echo "4. The native library should now be available at runtime"
echo ""
echo "Note: You may need to run this script again after 'flutter clean'"
echo ""
