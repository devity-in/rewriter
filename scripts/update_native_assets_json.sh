#!/bin/bash

# Script to manually update native_assets.json with the MediaPipe GenAI library
# This is a workaround for Flutter's native-assets not executing build.dart

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Find the native_assets.json file
NATIVE_ASSETS_JSON=$(find .dart_tool/flutter_build -name "native_assets.json" 2>/dev/null | head -1)

if [ -z "$NATIVE_ASSETS_JSON" ]; then
    # Create directory if it doesn't exist
    mkdir -p .dart_tool/flutter_build/default
    NATIVE_ASSETS_JSON=".dart_tool/flutter_build/default/native_assets.json"
fi

echo "Updating: $NATIVE_ASSETS_JSON"

# Get absolute path to the library
LIB_PATH="$PROJECT_ROOT/build/native_assets/macos/arm64/libllm_inference_engine.dylib"

if [ ! -f "$LIB_PATH" ]; then
    echo "❌ Library not found at: $LIB_PATH"
    echo "   Run ./scripts/fix_native_assets.sh first"
    exit 1
fi

# Convert to absolute path
LIB_ABSOLUTE_PATH=$(cd "$(dirname "$LIB_PATH")" && pwd)/$(basename "$LIB_PATH")

# Create the native_assets.json entry
# Format based on what build.dart would generate
cat > "$NATIVE_ASSETS_JSON" <<EOF
{
  "format-version": [1, 0, 0],
  "native-assets": {
    "package:mediapipe_genai/src/io/third_party/mediapipe/generated/mediapipe_genai_bindings.dart": {
      "macos": {
        "arm64": {
          "link_mode": "dynamic",
          "path": "$LIB_ABSOLUTE_PATH"
        }
      }
    }
  }
}
EOF

echo "✅ Updated native_assets.json"
echo "   Asset ID: package:mediapipe_genai/src/io/third_party/mediapipe/generated/mediapipe_genai_bindings.dart"
echo "   Library path: $LIB_ABSOLUTE_PATH"
