# Native Assets Build Issue

## Problem
The `mediapipe_genai` package requires native libraries to be downloaded during the build process via a `build.dart` script, but Flutter is not automatically triggering this script.

## Evidence
1. ✅ Native assets are enabled: `flutter config --enable-native-assets` shows enabled
2. ✅ Package `build.dart` exists and contains download logic
3. ✅ Download URL is accessible (HTTP 200)
4. ❌ `native_assets.json` is empty: `{"native-assets":{}}`
5. ❌ No `build-log*.txt` files are generated
6. ❌ No native library files (`.dylib`) in build directory
7. ❌ Flutter build output shows no native asset processing messages

## Root Cause
Flutter's native-assets feature (experimental) may not be automatically executing `build.dart` scripts from packages during `flutter pub get` or `flutter build`. This is likely a limitation of the current experimental implementation.

## Current Status
- Package: `mediapipe_genai: ^0.0.1`
- Flutter: Master channel (3.40.0-1.0.pre-451)
- Native assets: Enabled
- Platform: macOS ARM64

## Workarounds to Try

### Option 1: Wait for Flutter Update
The native-assets feature is experimental and may be improved in future Flutter versions.

### Option 2: Check Package Issues
Check the package's GitHub for known issues:
- https://github.com/google/flutter-mediapipe/issues

### Option 3: Use Alternative Approach
Consider using the Gemini API instead until native-assets support is fully working.

## Files Created for Debugging
- `scripts/test_native_assets.sh` - Test script to verify package setup
- `scripts/setup_local_ai.sh` - Setup script (updated with diagnostics)

## Next Steps
1. Monitor Flutter updates for native-assets improvements
2. Check package GitHub for workarounds or updates
3. Consider filing an issue with Flutter or the package maintainers
4. Use Gemini API as fallback for now

