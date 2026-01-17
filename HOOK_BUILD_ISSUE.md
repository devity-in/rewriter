# Native Assets Hook Build Issue

## Problem
The `hook/build.dart` in `flutter-mediapipe/packages/mediapipe-task-genai` is failing because Flutter is passing a nested config structure, but `native_assets_cli` 0.6.0 expects a flat structure.

## Error
```
FormatException: No value was provided for required key: target_os
```

The config file has:
```json
{
  "config": {
    "extensions": {
      "code_assets": {
        "target_os": "macos",
        "target_architecture": "arm64"
      }
    }
  }
}
```

But `native_assets_cli` expects:
```json
{
  "config": {
    "target_os": "macos",
    "target_architecture": "arm64"
  }
}
```

## Root Cause
This appears to be a version mismatch between:
- Flutter 3.38.3 (stable channel)
- native_assets_cli 0.6.0 (which uses hooks)

The newer hook-based API expects a different config format than what Flutter is providing.

## Attempted Fixes

1. ✅ Updated `build.dart` to use new API (`config` and `output` parameters)
2. ✅ Changed from `buildConfig.targetOS` to `config.targetOS`
3. ✅ Updated asset creation to use `output.addAsset(NativeCodeAsset(...))`
4. ❌ Tried flattening the config JSON - didn't work (Config reads directly from file)
5. ❌ Tried extracting nested values and adding to args - Config doesn't accept those args

## Current Status
The hook is being called by Flutter, but fails during config parsing because `target_os` is nested.

## Potential Solutions

### Option 1: Downgrade native_assets_cli
Use an older version that matches Flutter 3.38.3's expected format.

### Option 2: Manually parse JSON and create BuildConfig
Bypass the `build()` function and manually create `BuildConfig` from the JSON file.

### Option 3: Update Flutter
Upgrade to a Flutter version that's compatible with native_assets_cli 0.6.0+.

### Option 4: Modify Config parsing
Patch the Config class to read from nested paths (complex, may break other things).

## Next Steps

1. Check Flutter version compatibility with native_assets_cli 0.6.0
2. Try manually constructing BuildConfig from JSON
3. Consider using the workaround scripts (`fix_native_assets.sh`) until this is resolved

## Files Modified
- `flutter-mediapipe/packages/mediapipe-task-genai/hook/build.dart` - Updated to new API
- `pubspec.yaml` - Using local packages
- `flutter-mediapipe/packages/mediapipe-task-genai/pubspec.yaml` - Using local mediapipe_core
