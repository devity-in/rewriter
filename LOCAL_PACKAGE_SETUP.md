# Local Flutter-MediaPipe Package Setup

## Overview
The project now uses local `flutter-mediapipe` packages instead of the published versions from pub.dev. This allows direct modifications to fix native-assets issues.

## Package Structure

```
rewriter/
├── flutter-mediapipe/              # Local flutter-mediapipe repository
│   └── packages/
│       ├── mediapipe-core/         # Core package (mediapipe_core)
│       └── mediapipe-task-genai/   # GenAI package (mediapipe_genai)
└── pubspec.yaml                    # Uses path dependencies
```

## Configuration

### pubspec.yaml Changes

**Main project (`rewriter/pubspec.yaml`):**
```yaml
dependencies:
  mediapipe_core:
    path: flutter-mediapipe/packages/mediapipe-core
  mediapipe_genai:
    path: flutter-mediapipe/packages/mediapipe-task-genai
```

**GenAI package (`flutter-mediapipe/packages/mediapipe-task-genai/pubspec.yaml`):**
```yaml
dependencies:
  mediapipe_core:
    path: ../mediapipe-core
```

## Build System

The `mediapipe_genai` package uses Flutter's native-assets hook system:
- Build script: `flutter-mediapipe/packages/mediapipe-task-genai/hook/build.dart`
- Uses `native_assets_cli` version `^0.6.0` (hook-based API)
- Downloads native libraries from Google Cloud Storage during build

## Making Changes

### To modify native-assets behavior:
1. Edit: `flutter-mediapipe/packages/mediapipe-task-genai/hook/build.dart`
2. Edit: `flutter-mediapipe/packages/mediapipe-task-genai/sdk_downloads.dart` (for URLs)

### To modify core functionality:
1. Edit: `flutter-mediapipe/packages/mediapipe-core/lib/`
2. Edit: `flutter-mediapipe/packages/mediapipe-task-genai/lib/`

### After making changes:
```bash
cd /Users/bw/abhishekthakur/rewriter
flutter pub get
flutter clean
flutter build macos --debug
```

## Current Issue

The native-assets hook (`build.dart`) should automatically download and register native libraries, but Flutter's native-assets system may not be executing it properly. 

### Potential Fixes:

1. **Ensure hook is being called**: Check Flutter logs during `flutter pub get` or `flutter build`
2. **Verify native-assets is enabled**: `flutter config --enable-native-assets`
3. **Check build output**: Look for `native_assets.json` files in `.dart_tool/flutter_build/`
4. **Manual workaround**: Use `scripts/fix_native_assets.sh` and `scripts/update_native_assets_json.sh`

## Testing Changes

1. Make changes to local packages
2. Run `flutter pub get` to pick up changes
3. Run `flutter clean` to clear build cache
4. Run `flutter build macos --debug` to test
5. Check if native libraries are downloaded and registered

## Notes

- The local packages are git submodules or cloned repositories
- Changes made here won't affect the upstream flutter-mediapipe repository
- Consider committing changes or creating patches if needed for team sharing
