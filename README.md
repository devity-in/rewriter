# Rewriter

A Flutter desktop application that runs in the system tray, monitors clipboard changes, detects English sentences, rewrites them using AI (Google Gemini API or local MediaPipe GenAI models), and automatically updates the clipboard with the rewritten content.

## Features

### ✅ Core Functionality
- **System Tray Integration** - Runs silently in the background with a menu bar icon
- **Automatic Clipboard Monitoring** - Detects when you copy English text
- **AI-Powered Rewriting** - Uses Google Gemini API or local MediaPipe GenAI models to rewrite text in various styles
- **Local AI Support** - Run AI models locally on your device (no API key required, works offline)
- **Smart Language Detection** - Only processes English sentences
- **Automatic Clipboard Update** - Rewritten text is automatically copied to clipboard

### ✅ Configuration & Settings
- **Settings Window** - Clean, modern UI for configuration
- **Secure API Key Storage** - API keys stored securely using `flutter_secure_storage`
- **Enable/Disable Toggle** - Control rewriting on/off
- **Writing Styles** - Choose from Professional, Casual, Concise, or Academic styles
- **Advanced Settings** - Configure debounce delay, min/max sentence length

### ✅ User Experience
- **System Notifications** - macOS notifications when rewrite completes
- **Preview Window** - See full rewritten text before selecting (with comparison view)
- **Status Indicators** - Visual feedback in tray icon (processing/ready/error)
- **Error Notifications** - User-friendly error messages
- **Keyboard Shortcuts** - Global shortcuts for quick access:
  - `Cmd+Shift+C` - Copy rewritten text
  - `Cmd+Shift+S` - Open settings
  - `Cmd+Shift+T` - Toggle enable/disable
- **History** - Access past rewrites (last 50 items)

## Requirements

- Flutter SDK ^3.10.1
- macOS (primary platform, Windows/Linux support planned)
- **For Gemini API**: Google Gemini API key ([Get one here](https://makersuite.google.com/app/apikey))
- **For Local AI**: MediaPipe GenAI model file (see [LOCAL_AI_SETUP.md](LOCAL_AI_SETUP.md) for setup instructions)

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd rewriter
   ```

2. **Enable native-assets (required for local AI)**
   ```bash
   flutter config --enable-native-assets
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the application**
   ```bash
   flutter run -d macos
   ```

## Setup

1. **First Launch**
   - The app will appear in your menu bar (system tray)
   - Click the tray icon → Settings
   - Choose your AI model:
     - **Gemini API**: Enter your Google Gemini API key
     - **Local AI**: Configure a local MediaPipe GenAI model (see [LOCAL_AI_SETUP.md](LOCAL_AI_SETUP.md))
   - Enable the app to start monitoring clipboard

2. **Configure Settings**
   - **AI Model Type**: Choose between Gemini API or Local AI
   - **Writing Style**: Choose Professional, Casual, Concise, or Academic
   - **Advanced Settings**: Adjust debounce delay and sentence length limits

## Usage

1. **Automatic Mode** (Default)
   - Copy any English text to clipboard
   - The app automatically detects and rewrites it
   - Rewritten text replaces the clipboard content
   - A notification appears when rewrite completes

2. **Preview Window**
   - When rewrite completes, you can open the preview window
   - View original and rewritten text side-by-side
   - Use comparison view to see all versions
   - Click "Copy" buttons or use keyboard shortcuts to select a version

3. **Keyboard Shortcuts**
   - `Cmd+Shift+C` - Copy the last rewritten text
   - `Cmd+Shift+S` - Open settings window
   - `Cmd+Shift+T` - Toggle rewriting on/off

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── core/
│   ├── models/              # Data models
│   └── services/            # Core services
├── ui/
│   ├── tray/               # System tray UI
│   ├── settings/            # Settings UI
│   ├── preview/             # Preview window UI
│   └── providers/           # State management
└── utils/                   # Utilities and constants
```

## Architecture

- **Services**: Modular services for clipboard, API, notifications, etc.
- **State Management**: Provider pattern for app state
- **Platform Integration**: Native macOS features (tray, notifications, hotkeys)
- **Secure Storage**: API keys stored securely using platform keychain

## Dependencies

- `system_tray` - System tray integration
- `clipboard` - Clipboard access
- `http` - API calls to Gemini
- `flutter_secure_storage` - Secure API key storage
- `provider` - State management
- `window_manager` - Window control
- `flutter_local_notifications` - System notifications
- `hotkey_manager` - Global keyboard shortcuts
- `mediapipe_core` - MediaPipe core dependencies
- `mediapipe_genai` - MediaPipe GenAI for local AI models
- `path_provider` - File system path utilities

## Development

### Running in Debug Mode
```bash
flutter run -d macos
```

### Building for Release
```bash
flutter build macos --release
```

## Configuration

The app stores configuration in:
- **API Key**: Secure storage (macOS Keychain)
- **Settings**: SharedPreferences (enabled state, style preferences, etc.)
- **History**: SharedPreferences (last 50 rewrites)

## AI Model Options

### Gemini API (Cloud)
- **Pros**: High quality, no setup required, always up-to-date
- **Cons**: Requires API key, needs internet connection, may have usage limits
- **Setup**: Enter your API key in Settings

### Local AI (MediaPipe GenAI)
- **Pros**: Works offline, no API key needed, privacy-focused, no usage limits
- **Cons**: Requires model download, may have lower quality than cloud APIs
- **Setup**: See [LOCAL_AI_SETUP.md](LOCAL_AI_SETUP.md) for detailed instructions

## Limitations & Future Work

- Currently optimized for macOS (Windows/Linux support planned)
- Single rewritten version (previously supported multiple versions)
- Local AI: Concurrent requests not supported (wait for one rewrite to complete)
- No auto-update mechanism
- Onboarding flow could be improved

See [PLAN.md](PLAN.md) for detailed roadmap and future enhancements.

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]
