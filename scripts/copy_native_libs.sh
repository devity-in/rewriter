#!/bin/bash

# Post-build script to copy native libraries to app bundle
# This ensures MediaPipe GenAI native libraries are available at runtime

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

NATIVE_LIB="build/native_assets/macos/arm64/libllm_inference_engine.dylib"

if [ ! -f "$NATIVE_LIB" ]; then
    echo "⚠️  Native library not found at $NATIVE_LIB"
    echo "   Run ./scripts/fix_native_assets.sh first"
    exit 0
fi

# Update native_assets.json first
if [ -f "scripts/update_native_assets_json.sh" ]; then
    ./scripts/update_native_assets_json.sh > /dev/null 2>&1
fi

# Find all app bundles and copy the library to both MacOS and Frameworks directories
find build/macos/Build/Products -name "rewriter.app" -type d | while read APP_BUNDLE; do
    MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
    FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
    
    if [ -d "$MACOS_DIR" ]; then
        cp "$NATIVE_LIB" "$MACOS_DIR/"
        echo "✅ Copied native library to: $MACOS_DIR"
    fi
    
    if [ -d "$FRAMEWORKS_DIR" ]; then
        cp "$NATIVE_LIB" "$FRAMEWORKS_DIR/"
        echo "✅ Copied native library to: $FRAMEWORKS_DIR"
    fi
done
