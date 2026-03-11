# Rewriter

A Flutter desktop application that monitors clipboard changes, detects English sentences, rewrites them using AI, and automatically updates the clipboard with the rewritten content. Ships with a built-in local LLM — works out of the box with zero configuration.

## Features

### Core Functionality
- **Built-in Local LLM** - Ships with a bundled GGUF model (NobodyWho) that runs entirely on your device — no API key, no internet, no setup
- **Automatic Clipboard Monitoring** - Detects when you copy English text
- **AI-Powered Rewriting** - Rewrites text in various styles using on-device or cloud AI
- **Multiple AI Backends** - NobodyWho (default, local GGUF), Gemini (cloud), Ollama (local server), or MediaPipe GenAI
- **GPU-Accelerated Inference** - Uses Metal on Apple Silicon for fast on-device generation
- **Smart Language Detection** - Only processes English sentences
- **Automatic Clipboard Update** - Rewritten text is automatically copied to clipboard

### Configuration & Settings
- **Settings Window** - Clean, modern UI for configuration
- **Secure API Key Storage** - API keys stored securely using `flutter_secure_storage`
- **Enable/Disable Toggle** - Control rewriting on/off
- **Writing Styles** - Choose from Professional, Casual, Concise, or Academic styles
- **Advanced Settings** - Configure debounce delay, min/max sentence length

### User Experience
- **System Tray Integration** - Runs in the background with a menu bar icon
- **System Notifications** - macOS notifications when rewrite completes
- **Preview Window** - See full rewritten text before selecting (with comparison view)
- **Status Indicators** - Visual feedback in tray icon (processing/ready/error)
- **Keyboard Shortcuts** - Global shortcuts for quick access:
  - `Cmd+Shift+C` - Copy rewritten text
  - `Cmd+Shift+S` - Open settings
  - `Cmd+Shift+T` - Toggle enable/disable
- **History** - Access past rewrites (last 50 items)
- **Dashboard** - Overview with today's/total rewrites, success vs error chart (1d/7d/30d), and recent history

## Requirements

- Flutter SDK ^3.10.1
- macOS (primary platform, Windows/Linux support planned)

**Optional (only if using alternative AI backends):**
- **Gemini API**: Google Gemini API key ([Get one here](https://makersuite.google.com/app/apikey))
- **Ollama**: [Ollama](https://ollama.ai) installed and running, plus a model (e.g. `ollama pull gemma2:2b`)
- **MediaPipe GenAI**: Model file in `.task` format (see [MediaPipe docs](https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference))

## Installation

### From DMG (recommended)

Download the latest `Rewriter-v*.dmg` from the [Releases](../../releases) page, open it, and drag the app to Applications.

### From Source

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd rewriter
   ```

2. **Download the bundled model**

   The GGUF model (~462 MB) is too large for Git and is hosted as a GitHub Release asset instead:
   ```bash
   gh release download model-assets --pattern 'model.gguf' --dir assets
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

1. **First Launch** - The app works immediately with the built-in NobodyWho model. No configuration needed.
2. **Optional** - Switch to a different AI backend in Settings > AI Model:
   - **NobodyWho** (default) - Bundled GGUF model, fully offline, GPU-accelerated
   - **Gemini API** - Cloud-based, requires API key
   - **Ollama** - Local server, requires Ollama installed with a pulled model
   - **Local AI (MediaPipe)** - Local model, requires model download

## Usage

1. **Automatic Mode** (Default)
   - Copy any English text to clipboard
   - The app automatically detects and rewrites it
   - Rewritten text replaces the clipboard content
   - A notification appears when rewrite completes

2. **Preview Window**
   - When rewrite completes, you can open the preview window
   - View original and rewritten text side-by-side
   - Click "Copy" buttons or use keyboard shortcuts to select a version

3. **Keyboard Shortcuts**
   - `Cmd+Shift+C` - Copy the last rewritten text
   - `Cmd+Shift+S` - Open settings window
   - `Cmd+Shift+T` - Toggle rewriting on/off

## AI Model Options

### NobodyWho (Default — Local GGUF)
- **Pros**: Works out of the box, fully offline, GPU-accelerated, no API key, privacy-focused
- **Cons**: Quality depends on bundled model size; larger models need more RAM
- **Setup**: None — selected by default

### Gemini API (Cloud)
- **Pros**: High quality, always up-to-date models
- **Cons**: Requires API key, needs internet connection, may have usage limits
- **Setup**: Enter your API key in Settings

### Ollama (Local server)
- **Pros**: Many models (Gemma, Llama, Mistral, etc.), easy to add new models, runs locally
- **Cons**: Requires Ollama installed and a model pulled
- **Setup**: Install [Ollama](https://ollama.ai), run `ollama serve`, set base URL and model name in Settings

### Local AI (MediaPipe GenAI)
- **Pros**: Works offline, no API key needed
- **Cons**: Requires model download, native asset setup
- **Setup**: Download a `.task` model file and configure the model path in Settings

## Project Structure

```
lib/
├── main.dart                 # Entry point (initializes NobodyWho runtime)
├── core/
│   ├── models/              # Data models (AppConfig, RewriteResult, etc.)
│   └── services/            # Core services
│       ├── nobodywho_service.dart  # NobodyWho local LLM (GGUF)
│       ├── gemini_service.dart     # Google Gemini API
│       ├── ollama_service.dart     # Ollama local server
│       ├── local_ai_service.dart   # MediaPipe GenAI
│       ├── rewriter_service.dart   # Orchestration
│       ├── clipboard_service.dart  # Clipboard monitoring
│       └── ...
├── ui/
│   ├── tray/                # System tray UI
│   ├── dashboard/           # Dashboard (metrics, chart, history)
│   ├── settings/            # Settings UI
│   ├── preview/             # Preview window UI
│   └── providers/           # State management
└── utils/                   # Utilities and constants
```

## Architecture

- **Services**: Modular services behind a common `AIService` interface
- **State Management**: Provider pattern for app state
- **Platform Integration**: Native macOS features (tray, notifications, hotkeys)
- **Secure Storage**: API keys stored securely using platform keychain
- **Local LLM**: NobodyWho wraps llama.cpp via Rust FFI for on-device GGUF inference

## Dependencies

- `nobodywho` - Local LLM inference (GGUF models via llama.cpp)
- `system_tray` - System tray integration
- `clipboard` - Clipboard access
- `http` - API calls (Gemini, Ollama)
- `flutter_secure_storage` - Secure API key storage
- `provider` - State management
- `window_manager` - Window control
- `flutter_local_notifications` - System notifications
- `hotkey_manager` - Global keyboard shortcuts
- `mediapipe_core` / `mediapipe_genai` - MediaPipe GenAI
- `path_provider` - File system path utilities
- `fl_chart` - Charts (dashboard)
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

### Building a DMG
```bash
./scripts/build_macos_dmg.sh
```

### Releases (DMG via GitHub Actions)

The CI workflow automatically downloads the model from the `model-assets` release before building. Trigger a release build via `workflow_dispatch` on the Actions tab.

#### Managing the Model Asset

The GGUF model is stored as a GitHub Release asset (not in Git) because it exceeds GitHub's 100 MB file-size limit.

**First-time setup** (upload the model):
```bash
gh release create model-assets --title "Model Assets" --notes "Large binary assets for CI builds"
gh release upload model-assets assets/model.gguf
```

**Updating the model**:
```bash
gh release upload model-assets assets/model.gguf --clobber
```

## Configuration

The app stores configuration in:
- **API Key**: Secure storage (macOS Keychain)
- **Settings**: SharedPreferences (enabled state, model type, style preferences, etc.)
- **History**: SharedPreferences (last 50 rewrites)
- **GGUF Model Cache**: Application documents directory (copied from bundled assets on first run)

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]
