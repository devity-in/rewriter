# Flutter Desktop Rewriter App - Project Plan

## Overview
A Flutter desktop application that runs in the system tray (status bar), monitors clipboard changes, detects English sentences, rewrites them using Google Gemini API, and automatically updates the clipboard with the rewritten content.

## Architecture

### Core Components

1. **System Tray Integration**
   - Runs as a background service in the system tray
   - Platform-specific implementations for macOS, Windows, Linux
   - Tray icon with context menu (Settings, Quit)

2. **Clipboard Monitor**
   - Continuous monitoring of clipboard changes
   - Debouncing to avoid excessive API calls
   - Detection of text vs non-text content

3. **Language Detection**
   - Detect if clipboard content contains English sentences
   - Filter out non-English or non-text content
   - Sentence boundary detection

4. **AI Rewriter Service**
   - Google Gemini API integration
   - Text rewriting with context preservation
   - Error handling and retry logic
   - API key management

5. **Configuration Management**
   - API key storage (secure, encrypted)
   - Settings UI (enable/disable, rewrite preferences)
   - User preferences persistence

## Technical Stack

### Flutter Packages

1. **System Tray**
   - `system_tray` - Cross-platform system tray support
   - `tray_manager` - Alternative option

2. **Clipboard**
   - `clipboard` - Clipboard access
   - `flutter_clipboard_manager` - Clipboard monitoring

3. **HTTP/API**
   - `http` or `dio` - For Gemini API calls
   - `google_generative_ai` - Official Gemini SDK (if available)

4. **Language Detection**
   - `language_detection` or custom implementation
   - `sentence_splitter` - For sentence boundary detection

5. **Storage**
   - `shared_preferences` - For settings storage
   - `flutter_secure_storage` - For API key storage

6. **State Management**
   - `provider` or `riverpod` - For app state management

7. **Platform Channels**
   - Native clipboard monitoring (if needed for better performance)

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── app.dart                  # Main app widget
├── core/
│   ├── config/
│   │   ├── app_config.dart  # App configuration
│   │   └── api_config.dart  # API configuration
│   ├── services/
│   │   ├── clipboard_service.dart      # Clipboard monitoring
│   │   ├── language_detector.dart      # Language detection
│   │   ├── gemini_service.dart         # Gemini API integration
│   │   └── storage_service.dart        # Secure storage
│   └── models/
│       └── rewrite_request.dart        # Data models
├── ui/
│   ├── tray_menu.dart       # System tray menu
│   ├── settings/
│   │   ├── settings_page.dart
│   │   └── api_key_dialog.dart
│   └── widgets/
│       └── status_indicator.dart
└── utils/
    ├── sentence_parser.dart  # Sentence extraction
    └── constants.dart        # App constants
```

## Features

### Phase 1: Core Functionality
- [ ] System tray integration
- [ ] Basic clipboard monitoring
- [ ] English sentence detection
- [ ] Gemini API integration
- [ ] Automatic clipboard rewriting

### Phase 2: Configuration
- [ ] Settings window
- [ ] API key management
- [ ] Enable/disable toggle
- [ ] Rewrite preferences (style, tone)

### Phase 3: Polish
- [x] Error handling and user feedback
- [ ] Rate limiting and API quota management
- [x] Logging and debugging tools
- [ ] Auto-update mechanism

### Phase 4: UX Improvements

#### Phase 4.1: Essential UX (High Impact) - IN PROGRESS
- [ ] **Notifications** - Show when rewrite completes
- [ ] **Preview Window** - See full text before selecting
- [ ] **Status Indicators** - Visual feedback in tray icon
- [ ] **Error Notifications** - User-friendly error messages

#### Phase 4.2: Power User Features (Medium Impact) - COMPLETED
- [x] **Keyboard Shortcuts** - Faster workflow (Cmd+Shift+R, Cmd+Shift+1/2)
- [x] **Enhanced Menu** - Better information display
- [x] **History** - Access past rewrites

#### Phase 4.3: Polish (Nice to Have)
- [ ] **Onboarding** - Better first experience
- [ ] **Quick Actions** - More interaction options
- [ ] **Smart Features** - Advanced functionality

## Implementation Details

### Clipboard Monitoring Strategy

1. **Polling Approach** (Initial)
   - Check clipboard every 500ms-1s
   - Compare with previous content
   - Trigger rewrite if changed and is English

2. **Event-Based Approach** (Optimized)
   - Use platform channels for native clipboard events
   - More efficient, less battery drain
   - Requires platform-specific code

### Language Detection

1. **Simple Approach**
   - Use regex to detect English sentence patterns
   - Check for common English words
   - Minimum sentence length validation

2. **Advanced Approach**
   - Use language detection library
   - Confidence threshold (e.g., >80% English)
   - Handle mixed-language content

### Gemini API Integration

**API Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent`

**Request Format**:
```json
{
  "contents": [{
    "parts": [{
      "text": "Rewrite this sentence: {original_text}"
    }]
  }]
}
```

**Response Handling**:
- Extract rewritten text from response
- Handle API errors gracefully
- Implement retry logic with exponential backoff

### Security Considerations

1. **API Key Storage**
   - Use `flutter_secure_storage` for API keys
   - Never log or expose API keys
   - Provide secure input dialog

2. **Data Privacy**
   - Process clipboard locally before sending to API
   - Consider adding option to process locally only
   - Clear sensitive data after processing

## User Experience Flow

1. **First Launch**
   - Show welcome dialog
   - Prompt for Gemini API key
   - Explain functionality

2. **Normal Operation**
   - App runs silently in system tray
   - Icon indicates status (active/inactive)
   - Clipboard monitoring runs in background

3. **Settings Access**
   - Right-click tray icon → Settings
   - Configure API key, preferences
   - Enable/disable rewriting

4. **Error Handling**
   - Show notifications for API errors
   - Log errors for debugging
   - Graceful degradation

## Platform-Specific Considerations

### macOS
- App must request accessibility permissions for clipboard monitoring
- Use `NSWorkspace.sharedWorkspace.notificationCenter` for clipboard events
- Sandbox considerations

### Windows
- Use `AddClipboardFormatListener` API
- Handle Windows-specific clipboard formats
- System tray integration via `Shell_NotifyIcon`

### Linux
- Use `GtkClipboard` for monitoring
- System tray via `libappindicator` or `StatusNotifierItem`

## Configuration File Structure

```yaml
# config.yaml (or preferences)
api_key: <encrypted>
enabled: true
rewrite_style: "professional"  # professional, casual, concise, etc.
min_sentence_length: 10
max_sentence_length: 500
debounce_ms: 1000
```

## Error Scenarios & Handling

1. **API Key Missing/Invalid**
   - Show notification
   - Open settings dialog
   - Disable rewriting

2. **API Rate Limit**
   - Queue requests
   - Show user notification
   - Implement backoff

3. **Network Errors**
   - Retry with exponential backoff
   - Show error notification
   - Cache last successful rewrite

4. **Clipboard Access Denied**
   - Request permissions
   - Show instructions
   - Fallback to manual mode

## Testing Strategy

1. **Unit Tests**
   - Language detection logic
   - Sentence parsing
   - API service mocking

2. **Integration Tests**
   - Clipboard monitoring
   - API integration
   - Settings persistence

3. **Manual Testing**
   - Cross-platform testing
   - Real-world clipboard scenarios
   - Performance testing

## Performance Considerations

1. **Debouncing**
   - Avoid rewriting on every clipboard change
   - Wait for stable clipboard content (1-2 seconds)

2. **Caching**
   - Cache recent rewrites
   - Avoid re-rewriting same content

3. **Resource Usage**
   - Minimize CPU usage
   - Efficient clipboard polling
   - Background processing

## UX Improvements Plan

### Current UX Issues
1. No visual feedback when rewriting is happening
2. Can't see full rewritten text before selecting (truncated in menu)
3. No notifications when rewrite completes
4. Errors only visible in console
5. No status indication (processing/ready/error)
6. Requires mouse interaction (no keyboard shortcuts)

### Phase 4.1: Essential UX Improvements

#### 1. Notifications
- macOS native notifications when rewrite starts/completes
- Show original text snippet and rewrite count
- Click notification to open preview window

#### 2. Preview Window
- Floating window showing:
  - Original text (full)
  - Both rewritten versions (full text)
  - Click to copy or keyboard shortcut (1/2)
- Appears near cursor or tray icon
- Auto-dismisses after selection or timeout (10s)
- Draggable and resizable

#### 3. Status Indicators
- Different tray icons:
  - Normal: app icon
  - Processing: animated/pulsing icon
  - Error: icon with badge/red tint
  - Disabled: grayed out icon
- Tooltip shows current status ("Processing...", "2 versions ready", "Error: API key invalid")

#### 4. Error Notifications
- User-friendly notifications for:
  - API errors (with retry option)
  - Network issues
  - Invalid API key
  - Rate limiting
- Error details in tray menu
- "Retry" option in menu

### Phase 4.2: Power User Features

#### 5. Keyboard Shortcuts
- `Cmd+Shift+R` - Show preview window
- `Cmd+Shift+1/2` - Select rewritten version 1/2
- `Cmd+Shift+S` - Open settings
- `Cmd+Shift+T` - Toggle enable/disable
- Global shortcuts (work system-wide)

#### 6. Enhanced Tray Menu
- Show status: "Processing...", "2 versions ready", "Error: API key invalid"
- Show original text snippet
- Expandable items for full rewritten text
- "View all" option to open preview window
- Recent rewrites history (last 5)

#### 7. History
- History panel in settings
- Recent rewrites in tray menu
- Search/filter history
- Export history

### Phase 4.3: Polish

#### 8. Onboarding
- Welcome dialog on first launch
- Quick setup wizard
- Tooltips/help in settings
- Example/test button

#### 9. Quick Actions
- "Rewrite current clipboard" manual trigger
- "Copy original back" undo option
- "Try different style" quick switch
- "Regenerate" for new versions

#### 10. Smart Features
- Auto-paste option (replace clipboard automatically)
- Context-aware rewriting (detect document type)
- Batch processing (rewrite multiple sentences)
- Custom rewrite prompts

## Future Enhancements

1. **Multiple AI Providers**
   - Support OpenAI, Claude, etc.
   - User-selectable provider

2. **Rewrite Styles**
   - Professional, casual, academic, creative
   - Custom style prompts

3. **Batch Processing**
   - Rewrite multiple sentences at once
   - Paragraph-level rewriting

## Development Phases

### Phase 1: MVP (Week 1-2)
- Basic Flutter desktop setup
- System tray integration
- Clipboard monitoring
- Simple English detection
- Gemini API integration
- Basic rewrite functionality

### Phase 2: Configuration (Week 3)
- Settings UI
- API key management
- Enable/disable toggle
- Error handling

### Phase 3: Polish (Week 4)
- Better error messages
- User feedback/notifications
- Performance optimization
- Documentation

## Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # System tray
  system_tray: ^2.0.0
  
  # Clipboard
  clipboard: ^0.1.3
  
  # HTTP
  http: ^1.1.0
  dio: ^5.4.0  # Alternative to http
  
  # Storage
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  
  # Language detection (optional)
  language_detection: ^0.1.0
  
  # State management
  provider: ^6.1.1
  
  # Utilities
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

## Getting Started Checklist

- [ ] Create Flutter desktop project
- [ ] Set up project structure
- [ ] Add dependencies
- [ ] Implement system tray
- [ ] Implement clipboard monitoring
- [ ] Implement language detection
- [ ] Integrate Gemini API
- [ ] Create settings UI
- [ ] Add error handling
- [ ] Test on all platforms
- [ ] Create documentation
- [ ] Build and package for distribution

## Notes

- Consider using `window_manager` for better window control
- May need platform-specific native code for optimal clipboard monitoring
- API costs: Monitor Gemini API usage and implement quotas if needed
- Privacy: Consider adding option to process text locally before sending to API


