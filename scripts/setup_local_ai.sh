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

# Run pub get
echo "Step 2: Installing dependencies..."
flutter pub get

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi
echo ""

# Check if native-assets is enabled
echo "Step 3: Verifying configuration..."
NATIVE_ASSETS_ENABLED=$(flutter config | grep "enable-native-assets" | grep -o "true\|false" || echo "unknown")

if [ "$NATIVE_ASSETS_ENABLED" = "true" ]; then
    echo "✅ Native-assets is enabled"
else
    echo "⚠️  Warning: Native-assets status is: $NATIVE_ASSETS_ENABLED"
    echo "   You may need to manually enable it: flutter config --enable-native-assets"
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
echo "For detailed instructions, see: LOCAL_AI_SETUP.md"
echo ""

