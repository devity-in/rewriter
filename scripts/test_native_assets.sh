#!/bin/bash

# Test script to verify native assets build for MediaPipe GenAI
# This helps diagnose why native assets aren't being downloaded

set -e

echo "=========================================="
echo "Testing Native Assets Build"
echo "=========================================="
echo ""

# Find the package directory
PACKAGE_DIR=$(find ~/.pub-cache/hosted/pub.dev -type d -name "mediapipe_genai-0.0.1" 2>/dev/null | head -1)

if [ -z "$PACKAGE_DIR" ]; then
    echo "❌ mediapipe_genai package not found in pub cache"
    exit 1
fi

echo "✅ Found package at: $PACKAGE_DIR"
echo ""

# Check if build.dart exists
if [ ! -f "$PACKAGE_DIR/build.dart" ]; then
    echo "❌ build.dart not found in package"
    exit 1
fi

echo "✅ Found build.dart"
echo ""

# Check SDK downloads file
if [ -f "$PACKAGE_DIR/sdk_downloads.dart" ]; then
    echo "✅ Found sdk_downloads.dart"
    echo ""
    echo "macOS ARM64 URL:"
    grep -A 2 "darwin_arm64" "$PACKAGE_DIR/sdk_downloads.dart" | grep "https" | head -1
    echo ""
else
    echo "❌ sdk_downloads.dart not found"
    exit 1
fi

# Try to test the download URL
DOWNLOAD_URL=$(grep -A 2 "darwin_arm64" "$PACKAGE_DIR/sdk_downloads.dart" | grep "https" | head -1 | sed 's/.*\(https[^"]*\).*/\1/' | tr -d ',' | tr -d '"' | tr -d ' ')

if [ -n "$DOWNLOAD_URL" ]; then
    echo "Testing download URL accessibility..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --head "$DOWNLOAD_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "✅ URL is accessible (HTTP $HTTP_CODE)"
    else
        echo "⚠️  URL returned HTTP $HTTP_CODE (may still work, but unusual)"
    fi
    echo ""
fi

# Check if we can run build.dart manually
echo "Attempting to run build.dart manually (dry-run)..."
cd "$PACKAGE_DIR"

# Check Dart version
DART_VERSION=$(dart --version 2>&1 | head -1)
echo "Dart version: $DART_VERSION"
echo ""

# Try running build.dart with --help or dry-run
echo "Running: dart build.dart --help"
dart build.dart --help 2>&1 | head -20 || echo "⚠️  Could not run with --help, trying other approach..."
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "If native assets still aren't building, the issue may be:"
echo "1. Flutter isn't calling build.dart during pub get"
echo "2. Native assets need to be triggered during 'flutter build' not 'flutter pub get'"
echo "3. There may be a bug in the Flutter native-assets feature"
echo ""
echo "Next steps:"
echo "- Try running: flutter clean && flutter pub get && flutter build macos --debug"
echo "- Check Flutter version: flutter --version"
echo "- Report issue: https://github.com/google/flutter-mediapipe/issues"

