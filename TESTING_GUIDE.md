# Testing Guide for Rewriter App

## Prerequisites

1. **Google Gemini API Key**: You need a valid API key from Google AI Studio
   - Get one at: https://makersuite.google.com/app/apikey
   - The app uses the `gemini-pro` model

2. **macOS Permissions**: The app may need clipboard access permissions
   - System Preferences → Security & Privacy → Privacy → Accessibility
   - Add the app if prompted

## How to Test

### Step 1: Run the App

```bash
flutter run -d macos
```

The app will:
- Start in the background
- Hide the main window after 500ms
- Show a tray icon in the menu bar (top right on macOS)

### Step 2: Configure API Key

1. **Find the tray icon** in your menu bar (look for the Rewriter icon)
2. **Click the tray icon** → Select "Settings"
3. **Enter your Gemini API key**:
   - Click "Configure" or "Change" next to API Key
   - Paste your API key
   - Click OK
4. **Enable the app**:
   - Toggle the switch to "ON" in the status card
   - Or use the tray menu → "Enable"

### Step 3: Test Clipboard Monitoring

1. **Copy some English text** to your clipboard:
   - Select and copy: `"This is a test sentence that needs to be rewritten."`
   - Or copy any English sentence (minimum 10 characters)

2. **Wait 1-2 seconds** (debounce delay)

3. **Check the tray menu**:
   - Click the tray icon
   - You should see rewritten text options appear:
     - "Select rewritten text:"
     - "1. [rewritten version 1]"
     - "2. [rewritten version 2]"

4. **Select a rewritten version**:
   - Click on one of the rewritten text options
   - It will be copied to your clipboard
   - Paste it somewhere to verify

### Step 4: Monitor Debug Output

Watch the console/terminal where you ran `flutter run` for debug messages:

```
ClipboardService: Starting monitoring (interval: 500ms)
RewriterService: Starting clipboard monitoring
ClipboardService: Clipboard changed (length: 45)
RewriterService: Clipboard changed, text length: 45
RewriterService: Processing text: "This is a test sentence that needs to be..."
RewriterService: Found 1 sentences
RewriterService: Sending to Gemini API: "This is a test sentence that needs to be..."
RewriterService: Received 2 results from API
RewriterService: Successfully rewritten 2 versions
  Version 1: "This sentence requires rewriting in a professional manner..."
  Version 2: "This text should be rephrased professionally with different..."
Rewritten texts available: 2
```

## Troubleshooting

### Issue: Tray icon not visible

**Solution:**
- Check if the app is running: `ps aux | grep rewriter`
- Look in the menu bar (may be hidden behind other icons)
- Try restarting the app
- Check console for errors during tray initialization

### Issue: No rewritten texts appear

**Check:**
1. **API Key configured?**
   - Open Settings from tray menu
   - Verify API key is set (should show "API Key Configured")

2. **App enabled?**
   - Check the status card in Settings
   - Toggle should be ON

3. **Text is English?**
   - The app only processes English text
   - Must contain common English words (>20% threshold)
   - Minimum 10 characters

4. **Text is a valid sentence?**
   - Must start with capital letter
   - Must contain spaces (multiple words)
   - Must be under 500 characters (default)

5. **Check debug output:**
   - Look for error messages in console
   - Check if API calls are being made
   - Verify clipboard changes are detected

### Issue: Clipboard not being monitored

**Check:**
- Look for "ClipboardService: Starting monitoring" in console
- Verify app is enabled in Settings
- Check macOS permissions (Accessibility)

### Issue: API errors

**Common errors:**
- `API Error: API key not valid` → Check your API key
- `API Error: Quota exceeded` → You've hit API limits
- `Request timeout` → Network issue or API slow

**Solutions:**
- Verify API key is correct
- Check your Google AI Studio quota
- Try again after a few seconds

## Testing Checklist

- [ ] App launches without errors
- [ ] Tray icon appears in menu bar
- [ ] Settings window opens from tray menu
- [ ] API key can be configured
- [ ] App can be enabled/disabled
- [ ] Clipboard monitoring starts when enabled
- [ ] English text is detected
- [ ] Rewritten texts appear in tray menu
- [ ] Selecting rewritten text copies it to clipboard
- [ ] Debug messages appear in console

## Quick Test Script

1. Copy this text: `"The quick brown fox jumps over the lazy dog."`
2. Wait 2 seconds
3. Click tray icon
4. You should see 2 rewritten versions
5. Click one to copy it
6. Paste to verify

## Advanced Testing

### Test Different Styles

1. Open Settings
2. Change "Writing Style" to:
   - Professional
   - Casual
   - Concise
   - Academic
3. Copy text and test each style

### Test Advanced Settings

1. Open Settings → Advanced Settings
2. Adjust:
   - **Debounce Delay**: How long to wait before processing (default: 1000ms)
   - **Min Sentence Length**: Minimum characters (default: 10)
   - **Max Sentence Length**: Maximum characters (default: 500)
3. Test with different values

### Test Edge Cases

- **Short text** (< 10 chars): Should be ignored
- **Long text** (> 500 chars): Should be ignored
- **Non-English text**: Should be ignored
- **Multiple sentences**: Should process first sentence or whole text
- **Empty clipboard**: Should be ignored
- **Same text copied twice**: Should only process once

## Debug Mode

All debug messages use `debugPrint()` and will appear in:
- Console when running `flutter run`
- Debug console in IDE
- Terminal output

Look for messages prefixed with:
- `ClipboardService:` - Clipboard monitoring
- `RewriterService:` - Text processing and rewriting
- `TrayManager:` - System tray operations

## Getting Help

If you're still having issues:
1. Check the console output for error messages
2. Verify all prerequisites are met
3. Try restarting the app
4. Check macOS system logs: `Console.app` → Search for "rewriter"

