# Flutter Desktop Rewriter App - Project Plan

## Overview
A Flutter desktop application that runs in the system tray (status bar), monitors clipboard changes, detects English sentences, rewrites them using Google Gemini API, and automatically updates the clipboard with the rewritten content.

## Current Status

**Version**: 1.0.0  
**Status**: Core functionality complete, ready for use  
**Primary Platform**: macOS (Windows/Linux support planned)  
**Current Phase**: Phase 4 - Production Readiness

### ✅ Completed Phases
- **Phase 1**: Core Functionality ✅
- **Phase 2**: Configuration & Settings ✅
- **Phase 3**: User Experience ✅

### 🚧 Current Phase: Production Readiness
- Rate limiting and API quota management
- Auto-update mechanism
- Onboarding flow improvements
- Build & distribution setup

### 📋 Upcoming Phases
- **Phase 5**: Platform Expansion (Windows/Linux)
- **Phase 6**: Enhanced Features (Quick Actions, Smart Features)
- **Phase 7**: Future Enhancements (Multiple Providers, Advanced Features)

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

## Project Structure - CURRENT

```
lib/
├── main.dart                 # Entry point
├── core/
│   ├── models/
│   │   ├── app_config.dart           # App configuration model
│   │   ├── rewrite_history_item.dart # History item model
│   │   └── rewrite_result.dart      # API result model
│   ├── services/
│   │   ├── clipboard_service.dart      # Clipboard monitoring
│   │   ├── language_detector.dart      # Language detection
│   │   ├── gemini_service.dart         # Gemini API integration
│   │   ├── storage_service.dart        # Secure storage
│   │   ├── rewriter_service.dart       # Main orchestration service
│   │   ├── notification_service.dart   # System notifications
│   │   ├── hotkey_service.dart         # Keyboard shortcuts
│   │   └── history_service.dart        # Rewrite history
├── ui/
│   ├── tray/
│   │   └── tray_manager.dart          # System tray menu
│   ├── settings/
│   │   ├── settings_page.dart         # Settings UI
│   │   └── api_key_dialog.dart        # API key input dialog
│   ├── preview/
│   │   ├── preview_window.dart        # Preview window UI
│   │   └── preview_manager.dart       # Preview window management
│   └── providers/
│       └── app_provider.dart          # App state management
└── utils/
    └── constants.dart                 # App constants
```

## Development Phases

### Phase 1: Core Functionality ✅ COMPLETED
**Status**: Complete  
**Goal**: Build the foundational features that make the app functional

- [x] System tray integration
- [x] Basic clipboard monitoring
- [x] English sentence detection
- [x] Gemini API integration
- [x] Automatic clipboard rewriting

### Phase 2: Configuration & Settings ✅ COMPLETED
**Status**: Complete  
**Goal**: Allow users to configure and customize the app

- [x] Settings window
- [x] API key management (secure storage)
- [x] Enable/disable toggle
- [x] Rewrite preferences (style, tone)
- [x] User preferences persistence

### Phase 3: User Experience ✅ COMPLETED
**Status**: Complete  
**Goal**: Improve usability and provide clear feedback

- [x] **Notifications** - Show when rewrite completes
- [x] **Preview Window** - See full text before selecting
- [x] **Status Indicators** - Visual feedback in tray icon
- [x] **Error Notifications** - User-friendly error messages
- [x] **Keyboard Shortcuts** - Faster workflow (Cmd+Shift+C, Cmd+Shift+S, Cmd+Shift+T)
- [x] **Enhanced Menu** - Better information display
- [x] **History** - Access past rewrites
- [x] Error handling and user feedback
- [x] Logging and debugging tools

### Phase 4: Production Readiness 🚧 IN PROGRESS
**Status**: Partially Complete  
**Goal**: Make the app production-ready and reliable

**Core Requirements**:
- [ ] **Rate Limiting & API Quota Management**
  - Track API usage
  - Implement rate limiting per time window
  - Show quota warnings
  - Queue requests when rate limited
- [ ] **Auto-Update Mechanism**
  - Check for updates on launch
  - Download and install updates automatically
  - Notify users of available updates
- [ ] **Onboarding Flow**
  - Welcome dialog on first launch
  - Quick setup wizard
  - Tooltips/help in settings
  - Example/test button
- [ ] **Build & Distribution**
  - Package for macOS distribution
  - Code signing and notarization
  - Create installer/DMG
  - Distribution documentation

**Nice to Have**:
- [ ] Advanced error recovery
- [ ] Usage analytics (opt-in)
- [ ] Crash reporting

### Phase 5: Platform Expansion 📋 PLANNED
**Status**: Not Started  
**Goal**: Support Windows and Linux platforms

**Windows Support**:
- [ ] Windows system tray integration
- [ ] Windows clipboard monitoring (event-based)
- [ ] Windows-specific UI adjustments
- [ ] Windows installer (MSI/EXE)
- [ ] Windows keyboard shortcuts

**Linux Support**:
- [ ] Linux system tray integration (StatusNotifierItem)
- [ ] Linux clipboard monitoring (GtkClipboard)
- [ ] Linux-specific UI adjustments
- [ ] Linux package formats (AppImage, DEB, RPM)
- [ ] Linux keyboard shortcuts

**Cross-Platform**:
- [ ] Platform detection and feature flags
- [ ] Platform-specific testing
- [ ] Documentation for each platform

### Phase 6: Enhanced Features 📋 PLANNED
**Status**: Not Started  
**Goal**: Add power-user features and advanced functionality

**Quick Actions**:
- [ ] "Rewrite current clipboard" manual trigger
- [ ] "Copy original back" undo option
- [ ] "Try different style" quick switch
- [ ] "Regenerate" for new versions
- [ ] Batch rewrite multiple sentences

**Smart Features**:
- [ ] Context-aware rewriting (detect document type)
- [ ] Custom rewrite prompts
- [ ] Auto-paste option (replace clipboard automatically)
- [ ] Advanced language detection (confidence threshold)
- [ ] Mixed-language content handling

**History Enhancements**:
- [ ] Search/filter history
- [ ] Export history (JSON/CSV)
- [ ] History statistics
- [ ] Favorite/bookmark rewrites

### Phase 7: Future Enhancements 🔮 FUTURE
**Status**: Ideas/Backlog  
**Goal**: Long-term improvements and new capabilities

**AI Provider Support**:
- [ ] Multiple AI providers (OpenAI, Claude, etc.)
- [ ] User-selectable provider
- [ ] Provider-specific optimizations
- [ ] Fallback providers

**Advanced Rewriting**:
- [ ] Multiple rewrite styles simultaneously
- [ ] Paragraph-level rewriting
- [ ] Document context preservation
- [ ] Custom style templates

**Integration & Automation**:
- [ ] Browser extension integration
- [ ] Text editor plugins
- [ ] API for third-party integrations
- [ ] Workflow automation (Shortcuts, Automator)

**Performance & Optimization**:
- [ ] Event-based clipboard monitoring (native)
- [ ] Request caching and deduplication
- [ ] Background processing optimization
- [ ] Battery usage optimization

## Implementation Details

### Clipboard Monitoring Strategy ✅ IMPLEMENTED

1. **Polling Approach** (Current Implementation)
   - Check clipboard every 500ms
   - Compare with previous content
   - Trigger rewrite if changed and is English
   - Debouncing (default 1000ms) to avoid excessive API calls

2. **Event-Based Approach** (Future Optimization)
   - Use platform channels for native clipboard events
   - More efficient, less battery drain
   - Requires platform-specific code

### Language Detection ✅ IMPLEMENTED

1. **Current Implementation** (Simple Approach)
   - Custom regex-based English sentence detection
   - Checks for common English words and patterns
   - Minimum sentence length validation (default: 10 chars)
   - Maximum sentence length limit (default: 500 chars)
   - Sentence boundary detection using punctuation

2. **Future Enhancement** (Advanced Approach)
   - Use language detection library for better accuracy
   - Confidence threshold (e.g., >80% English)
   - Handle mixed-language content

### Gemini API Integration ✅ IMPLEMENTED

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

**Current Implementation**:
- Single rewritten version (simplified from original multi-version design)
- Automatically copies rewritten text to clipboard
- Shows success/error notifications
- Saves to history for later access

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

## UX Improvements - Completed ✅

**Status**: Phase 3 completed - All essential UX improvements implemented

### ✅ Implemented Features

**Notifications**:
- macOS native notifications when rewrite completes
- Show original text snippet
- Click notification to open preview window

**Preview Window**:
- Floating window showing original and rewritten text (full)
- Click to copy or keyboard shortcuts
- Appears near cursor or tray icon
- Auto-dismisses after selection or timeout
- Draggable and resizable

**Status Indicators**:
- Different tray icons for different states (normal, processing, error, disabled)
- Tooltip shows current status

**Error Notifications**:
- User-friendly notifications for API errors, network issues, invalid API key
- Error details in tray menu

**Keyboard Shortcuts**:
- `Cmd+Shift+C` - Copy rewritten text (if available)
- `Cmd+Shift+S` - Open settings
- `Cmd+Shift+T` - Toggle enable/disable
- Preview window shortcuts (Cmd+Shift+R, Cmd+Shift+1/2)
- Global shortcuts (work system-wide on macOS)

**Enhanced Tray Menu**:
- Shows status and original text snippet
- Recent rewrites history
- "View all" option to open preview window

**History**:
- History panel in settings
- Recent rewrites in tray menu

### 📋 Remaining UX Improvements

See **Phase 4: Production Readiness** for onboarding improvements  
See **Phase 6: Enhanced Features** for quick actions and smart features

## Future Enhancements

**Note**: See **Phase 7: Future Enhancements** for detailed roadmap of long-term improvements.

Key areas for future development:
- Multiple AI provider support (OpenAI, Claude, etc.)
- Advanced rewrite styles and custom prompts
- Batch processing and paragraph-level rewriting
- Third-party integrations and automation
- Performance optimizations

## Historical Development Timeline

**Note**: This section documents the original development timeline. See "Development Phases" above for current status.

### Original Phase 1: MVP (Week 1-2) ✅
- Basic Flutter desktop setup
- System tray integration
- Clipboard monitoring
- Simple English detection
- Gemini API integration
- Basic rewrite functionality

### Original Phase 2: Configuration (Week 3) ✅
- Settings UI
- API key management
- Enable/disable toggle
- Error handling

### Original Phase 3: Polish (Week 4) ✅
- Better error messages
- User feedback/notifications
- Performance optimization
- Documentation

## Dependencies (pubspec.yaml) - CURRENT

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # System tray
  system_tray: ^2.0.3
  
  # Clipboard
  clipboard: ^0.1.3
  
  # HTTP for API calls
  http: ^1.2.0
  
  # Storage
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  
  # State management
  provider: ^6.1.1
  
  # Utilities
  intl: ^0.19.0
  
  # Window management
  window_manager: ^0.3.7
  flutter_local_notifications: ^19.5.0
  hotkey_manager: ^0.2.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

**Note**: Language detection is implemented as a custom service (`LanguageDetector`) rather than using an external package.

## Getting Started Checklist

- [x] Create Flutter desktop project
- [x] Set up project structure
- [x] Add dependencies
- [x] Implement system tray
- [x] Implement clipboard monitoring
- [x] Implement language detection
- [x] Integrate Gemini API
- [x] Create settings UI
- [x] Add error handling
- [x] Test on macOS (primary platform)
- [x] Create documentation
- [ ] Build and package for distribution
- [ ] Test on Windows and Linux

## Notes

- Consider using `window_manager` for better window control
- May need platform-specific native code for optimal clipboard monitoring
- API costs: Monitor Gemini API usage and implement quotas if needed
- Privacy: Consider adding option to process text locally before sending to API


