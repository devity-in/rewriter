# Native Library Fix for MediaPipe GenAI

## Problem
Flutter's native-assets feature is not automatically executing the `build.dart` script from the `mediapipe_genai` package, resulting in missing native libraries at runtime with the error:
```
Couldn't resolve native function 'LlmInferenceEngine_CreateSession'
symbol not found
```

## Solution
A workaround script has been created to manually download and install the native library.

## Quick Fix

Run the fix script (downloads library and updates native_assets.json):
```bash
./scripts/fix_native_assets.sh
```

Then rebuild:
```bash
flutter build macos --debug
./scripts/copy_native_libs.sh
```

Or run the app (will auto-copy library):
```bash
flutter run -d macos
```

**Important**: After running `flutter clean`, you need to run `./scripts/fix_native_assets.sh` again to re-download and register the library.

## What the Scripts Do

### `scripts/fix_native_assets.sh`
1. Downloads the MediaPipe GenAI native library (`libllm_inference_engine.dylib`) from Google Cloud Storage
2. Places it in `build/native_assets/macos/arm64/`
3. Copies it to the app bundle if it exists

### `scripts/copy_native_libs.sh`
1. Updates `native_assets.json` files to register the library with Flutter's native-assets system
2. Copies the native library from `build/native_assets/` to all app bundles in `build/macos/Build/Products/`
3. Copies to both `Contents/MacOS/` and `Contents/Frameworks/` directories
4. Should be run after each build

### `scripts/update_native_assets_json.sh`
1. Manually updates Flutter's `native_assets.json` files to register the library
2. Uses the asset ID that `mediapipe_genai` package expects: `package:mediapipe_genai/src/io/third_party/mediapipe/generated/mediapipe_genai_bindings.dart`
3. Links to the downloaded library file

## Integration with Build Process

To automatically copy the library after each build, you can:

1. **Manual approach**: Run `./scripts/copy_native_libs.sh` after each build
2. **Automated approach**: Add a post-build script to your CI/CD or development workflow

## Files Modified
- `pubspec.yaml`: Added `native_assets_cli` as dev dependency (though it's discontinued, kept for reference)
- Created `scripts/fix_native_assets.sh`: Downloads and installs native library
- Created `scripts/copy_native_libs.sh`: Copies library to app bundle

## Library Location
- Downloaded to: `build/native_assets/macos/arm64/libllm_inference_engine.dylib`
- Copied to: 
  - `build/macos/Build/Products/*/rewriter.app/Contents/MacOS/libllm_inference_engine.dylib`
  - `build/macos/Build/Products/*/rewriter.app/Contents/Frameworks/libllm_inference_engine.dylib`
- Registered in: `.dart_tool/flutter_build/*/native_assets.json`

## Notes
- The native library is ~15MB
- You need to run `fix_native_assets.sh` again after `flutter clean`
- The library URL is hardcoded for macOS ARM64 - update the script if you need x64 or other platforms

## Future Improvements
- Integrate into Xcode build phases
- Automatically detect and download for all platforms
- Check for library updates
- Integrate with Flutter's native-assets system when it's fully working
