# Build Performance Notes

## Why Builds Take Time

### First Build (After `flutter clean`)
1. **Native Library Download**: ~15MB file from Google Cloud Storage
   - Takes 30-60 seconds depending on network speed
   - Only happens once, then cached

2. **Config Flattening**: The hook flattens nested config structure
   - Takes < 1 second
   - Only happens if config isn't already flattened

3. **Flutter Build Process**: Standard Flutter build steps
   - Compiling Dart code
   - Processing assets
   - Building macOS app bundle

### Subsequent Builds
1. **Config Check**: Fast (< 1 second) - checks if already flattened
2. **File Existence Check**: Fast (< 1 second) - skips download if file exists
3. **Flutter Build**: Normal build time (depends on code changes)

## Optimizations Made

1. ✅ **Skip download if file exists** - Checks file existence before downloading
2. ✅ **Skip config flattening if already done** - Checks if config is already flattened
3. ✅ **Use synchronous file operations** - Faster for existence checks
4. ✅ **Fixed double "lib" prefix bug** - Prevents incorrect file names

## Expected Build Times

- **First build (after clean)**: 60-90 seconds (includes 15MB download)
- **Subsequent builds**: 10-30 seconds (normal Flutter build time)
- **Hot reload**: < 5 seconds (Dart code changes only)

## If Build is Still Slow

1. **Check network**: First build downloads from Google Cloud Storage
2. **Check disk space**: Ensure enough space for 15MB library
3. **Check Flutter version**: Some versions have known performance issues
4. **Check for other processes**: Other Flutter/Dart processes might be slowing things down

## Monitoring Build Progress

The hook logs to:
- Console output (stdout): Shows flattening and download status
- Build log: `build/live-run-build-log.txt` (if created)

Look for:
- `✅ Flattened config` - Config processing complete
- `✅ Native library already exists` - Download skipped (fast)
- `📥 Downloading native library` - Download in progress (slow)
