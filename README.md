# Rewriter

A Flutter desktop application that runs in the system tray, monitors clipboard changes, detects English sentences, rewrites them using AI (Google Gemini API, Ollama, or local MediaPipe GenAI models), and automatically updates the clipboard with the rewritten content.

## Features

### ✅ Core Functionality
- **System Tray Integration** - Runs silently in the background with a menu bar icon
- **Automatic Clipboard Monitoring** - Detects when you copy English text
- **AI-Powered Rewriting** - Uses Google Gemini API, Ollama, or local MediaPipe GenAI models to rewrite text in various styles
- **Multiple AI Backends** - Gemini (cloud), Ollama (local server), or Local AI (MediaPipe GenAI, no API key, works offline)
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
- **Dashboard** - Overview with today’s/total rewrites, success vs error chart (1d/7d/30d by time or day), and recent history

## Requirements

- Flutter SDK ^3.10.1
- macOS (primary platform, Windows/Linux support planned)
- **For Gemini API**: Google Gemini API key ([Get one here](https://makersuite.google.com/app/apikey))
- **For Ollama**: [Ollama](https://ollama.ai) installed and running (e.g. `ollama serve`), plus a model (e.g. `ollama pull gemma2:2b`)
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
   - Click the tray icon → Settings (or open Dashboard for overview)
   - Choose your AI model:
     - **Gemini API**: Enter your Google Gemini API key
     - **Ollama**: Set base URL (default `http://localhost:11434`) and model name (e.g. `gemma2:2b`). Use “List models” to pick from installed models.
     - **Local AI**: Configure a local MediaPipe GenAI model (see [LOCAL_AI_SETUP.md](LOCAL_AI_SETUP.md))
   - Enable the app to start monitoring clipboard

2. **Configure Settings**
   - **AI Model Type**: Choose Gemini API, Ollama, or Local AI
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
│   └── services/            # Core services (clipboard, Gemini, Ollama, local AI, etc.)
├── ui/
│   ├── tray/                # System tray UI
│   ├── dashboard/            # Dashboard (metrics, chart, history)
│   ├── settings/            # Settings UI
│   ├── preview/              # Preview window UI
│   └── providers/           # State management
└── utils/                    # Utilities and constants
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
- `fl_chart` - Charts (dashboard success/error over time)
- `intl` - Date/time formatting

## Development

### Running in Debug Mode
```bash
flutter run -d macos
```

### Building for Release
```bash
flutter build macos --release
```

### Releases (DMG via GitHub Actions)
Pushing a version tag builds the macOS app, creates a DMG, and uploads it to a GitHub Release:
```bash
git tag v1.0.0
git push origin v1.0.0
```
The workflow (`.github/workflows/release-macos.yml`) runs on tag push `v*`, builds the app, creates `Rewriter-<tag>.dmg`, and attaches it to the release.

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

### Ollama (Local server)
- **Pros**: Many models (Gemma, Llama, Mistral, etc.), easy to add new models, no API key, runs locally
- **Cons**: Requires Ollama installed and a model pulled (e.g. `ollama pull gemma2:2b`)
- **Setup**: Install [Ollama](https://ollama.ai), run `ollama serve`, then in Settings set base URL and model name (or use “List models” to pick one)

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
