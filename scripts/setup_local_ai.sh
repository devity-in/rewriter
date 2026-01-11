#!/bin/bash

# Setup script for Local AI (MediaPipe GenAI)
# This script helps configure Flutter for MediaPipe GenAI

set -e

echo "=========================================="
echo "Local AI Setup - MediaPipe GenAI"
echo "=========================================="
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "Please install Flutter first: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"
echo ""

# Enable native-assets
echo "Step 1: Enabling native-assets experiment..."
flutter config --enable-native-assets

if [ $? -eq 0 ]; then
    echo "✅ Native-assets enabled successfully"
else
    echo "❌ Failed to enable native-assets"
    exit 1
fi
echo ""

# Clean previous build artifacts
echo "Step 2: Cleaning previous build artifacts..."
flutter clean

if [ $? -eq 0 ]; then
    echo "✅ Build cleaned successfully"
else
    echo "⚠️  Warning: Clean had issues, continuing anyway..."
fi
echo ""

# Run pub get
echo "Step 3: Installing dependencies..."
flutter pub get

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi
echo ""

# Build native assets by running a build
echo "Step 4: Building native assets..."
echo "   Native assets are downloaded during the build process"
echo "   This may take a few minutes on first run (downloads native libraries)..."
flutter build macos --debug --no-codesign 2>&1 | tee /tmp/flutter_build.log

# Check for build log from mediapipe package
BUILD_LOG=$(find build -name "*build-log*.txt" 2>/dev/null | head -1)
if [ -n "$BUILD_LOG" ]; then
    echo ""
    echo "   Native assets build log found:"
    tail -20 "$BUILD_LOG" | sed 's/^/   /'
fi
echo ""

# Check if native-assets is enabled
echo "Step 5: Verifying configuration..."
NATIVE_ASSETS_ENABLED=$(flutter config | grep "enable-native-assets" | grep -o "true\|false" || echo "unknown")

if [ "$NATIVE_ASSETS_ENABLED" = "true" ]; then
    echo "✅ Native-assets is enabled"
else
    echo "⚠️  Warning: Native-assets status is: $NATIVE_ASSETS_ENABLED"
    echo "   You may need to manually enable it: flutter config --enable-native-assets"
fi
echo ""

# Check if native assets were actually built
echo "Step 6: Checking native assets..."
NATIVE_ASSETS_JSON=$(find .dart_tool -name "native_assets.json" 2>/dev/null | head -1)
if [ -n "$NATIVE_ASSETS_JSON" ]; then
    # Check if the JSON actually has asset entries (not just empty object)
    ASSET_COUNT=$(cat "$NATIVE_ASSETS_JSON" 2>/dev/null | grep -c '": {' || echo "0")
    if [ "$ASSET_COUNT" -gt 1 ]; then
        echo "✅ Native assets file found and contains $((ASSET_COUNT - 1)) asset(s)"
        
        # Check for downloaded native library files
        NATIVE_LIBS=$(find build -name "*.dylib" -o -name "libllm_inference_engine*" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$NATIVE_LIBS" -gt 0 ]; then
            echo "✅ Found $NATIVE_LIBS native library file(s)"
        else
            echo "⚠️  Warning: Native library files not found in build directory"
            echo "   The native assets JSON exists but libraries may not have downloaded"
        fi
    else
        echo "⚠️  Warning: Native assets file exists but appears empty"
        echo "   The build.dart script may have failed to download native libraries"
        echo "   Check build logs: find build -name '*build-log*.txt'"
    fi
else
    echo "⚠️  Warning: Native assets file not found after build"
    echo "   Native assets may not have been built"
    echo "   Try: flutter clean && flutter pub get && flutter build macos --debug"
fi
echo ""

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Obtain a MediaPipe GenAI model (.task file)"
echo "2. Place it in ~/Downloads or configure a model URL in settings"
echo "3. Open the app and select 'Local AI' as your model type"
echo ""
echo "⚠️  Important: If you encounter 'symbol not found' errors at runtime:"
echo "   1. Check that native assets were downloaded (see Step 6 above)"
echo "   2. Verify build logs don't show download errors"
echo "   3. Try: flutter clean && flutter pub get && flutter build macos --debug"
echo "   4. Check package GitHub issues: https://github.com/google/flutter-mediapipe/issues"
echo ""
echo "For detailed instructions, see: LOCAL_AI_SETUP.md"
echo ""

