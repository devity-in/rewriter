# Local AI Setup Guide - MediaPipe GenAI

This guide will help you set up the local AI model using MediaPipe GenAI for on-device text rewriting.

## Overview

MediaPipe GenAI allows you to run generative AI models locally on your device without needing an internet connection or API keys. The app supports both CPU and GPU inference, with automatic fallback to CPU if GPU is not available.

## Prerequisites

1. **Flutter SDK** (^3.10.1) with native-assets experiment enabled
2. **macOS** (primary platform - Windows/Linux support coming soon)
3. **Model file** (.task format) - See "Obtaining Models" section below

## Step 1: Enable Native Assets

MediaPipe GenAI requires the `native-assets` experiment to be enabled in Flutter:

```bash
flutter config --enable-native-assets
```

To disable it later (if needed):
```bash
flutter config --no-enable-native-assets
```

## Step 2: Install Dependencies

The required dependencies are already in `pubspec.yaml`:
- `mediapipe_core: ^0.0.1`
- `mediapipe_genai: ^0.0.1`
- `path_provider: ^2.1.1`

Run:
```bash
flutter pub get
```

## Step 3: Obtain a Model

According to MediaPipe GenAI documentation, models must be:
1. Downloaded from Kaggle (requires account and Terms of Service acceptance)
2. Self-hosted at a URL of your choosing
3. Downloaded at runtime by the app

### Option A: Download from Kaggle

1. **Create a Kaggle Account**
   - Visit [Kaggle.com](https://www.kaggle.com)
   - Create an account and accept the Terms of Service

2. **Get Kaggle API Credentials**
   - Go to your Kaggle account settings
   - Create a new API token (downloads `kaggle.json`)
   - Extract your username and API key

3. **Find MediaPipe GenAI Models**
   - Search Kaggle for MediaPipe GenAI models
   - Look for models in `.task` format
   - Common models include:
     - `functiongemma_270m.task` (smaller, faster)
     - `gemma_2b.task` (larger, better quality)

4. **Configure in App**
   - Open Settings → Local AI Model
   - Enter your Kaggle username and API key
   - Enter the Kaggle model URL
   - The app will download and cache the model automatically

### Option B: Self-Host a Model

1. **Download Model from Kaggle**
   - Follow steps 1-3 from Option A
   - Download the `.task` file manually

2. **Host the Model**
   - Upload the `.task` file to a web server (your own server, GitHub Releases, etc.)
   - Get a direct download URL to the file

3. **Configure in App**
   - Open Settings → Local AI Model
   - Enter the model URL
   - The app will download and cache the model automatically

### Option C: Use Local Server (Recommended for Development)

1. **Move Model to Project**
   - Copy your `.task` model file from `~/Downloads` to `./models/` directory in the project
   - Example: `cp ~/Downloads/functiongemma_270m.task ./models/`

2. **Start the Model Server**
   ```bash
   # Using Python script (recommended)
   python3 scripts/serve_models.py

   # Or using shell script
   ./scripts/serve_models.sh
   ```
   The server will start on `http://localhost:8000` by default.

3. **Configure in App**
   - Open Settings → Local AI Model
   - Enter model URL: `http://localhost:8000/your_model.task`
   - The app will download and cache the model automatically

**Note**: Keep the server running while downloading the model. Once downloaded, the model is cached locally and you can stop the server.

### Option D: Place Model Manually

1. **Download Model**
   - Download a `.task` model file from Kaggle or other source

2. **Place in Downloads Folder**
   - Put the `.task` file in your `~/Downloads` folder
   - The app will automatically detect it

3. **Or Bundle with App**
   - Place the model in `assets/models/`
   - Update `pubspec.yaml` to include it:
     ```yaml
     assets:
       - assets/models/your_model.task
     ```
   - The app will copy it to the filesystem on first use

## Step 4: Configure the App

1. **Open Settings**
   - Click the tray icon → Settings
   - Or use keyboard shortcut: `Cmd+Shift+S`

2. **Select Local AI Model**
   - Under "AI Model Type", select "Local AI"
   - The app will automatically detect available models

3. **Configure Model (if needed)**
   - **Model URL**: URL to download model from
     - For local server: `http://localhost:8000/your_model.task`
     - For self-hosted: Your model URL
     - Leave empty if model is in Downloads or assets
   - **Kaggle Username**: Your Kaggle username (if downloading from Kaggle)
   - **Kaggle API Key**: Your Kaggle API key (if downloading from Kaggle)

4. **Save Settings**
   - Click "Save" to apply changes
   - The app will initialize the local AI model in the background
   - If using a model URL, ensure the server is running (for local server)

## Step 5: Verify Setup

1. **Check Initialization**
   - The app will show a notification when the model is ready
   - Check the tray menu for status: "Local AI: Ready" or "Local AI: Initializing..."

2. **Test the Model**
   - Copy some English text to clipboard
   - The app should automatically rewrite it using the local model
   - No internet connection required!

## Troubleshooting

### Native Assets Not Available

**Error**: "Local AI native assets not available"

**Solution**:
1. Ensure native-assets is enabled:
   ```bash
   flutter config --enable-native-assets
   ```
2. Run `flutter pub get`
3. Clean and rebuild:
   ```bash
   flutter clean
   flutter run
   ```

### Model Not Found

**Error**: "Local AI model not available"

**Solutions**:
1. Check that a `.task` file exists in `~/Downloads`
2. Or configure a model URL in settings
3. Or place the model in `assets/models/` and update `pubspec.yaml`

### GPU Not Available

**Note**: The app automatically falls back to CPU if GPU is not available. This is normal and expected on some systems.

**To force CPU mode**: The app will automatically use CPU if GPU initialization fails.

### Model Download Fails

**Error**: "Failed to download model"

**Solutions**:
1. Check your internet connection
2. Verify the model URL is correct and accessible
3. For Kaggle downloads, verify your username and API key are correct
4. Check that you've accepted Kaggle's Terms of Service

### Concurrent Generation Error

**Error**: "Another rewrite is already in progress"

**Note**: MediaPipe GenAI doesn't support concurrent generation requests. Wait for the current rewrite to complete before copying new text.

## Model Recommendations

### For Best Performance (GPU)
- Use GPU-compatible models
- Recommended: `functiongemma_270m.task` or `gemma_2b.task` (GPU variant)

### For CPU-Only Systems
- Use CPU-compatible models
- Smaller models perform better on CPU
- Recommended: `functiongemma_270m.task` (CPU variant)

## Performance Tips

1. **Model Size**: Smaller models (270M) are faster but may have lower quality. Larger models (2B+) have better quality but are slower.

2. **GPU vs CPU**: GPU inference is significantly faster. If you have a compatible GPU, use GPU models.

3. **Caching**: Models are cached locally after first download, so subsequent app launches are faster.

4. **Memory**: Larger models require more RAM. Ensure you have sufficient memory available.

## Limitations

- **Concurrent Requests**: MediaPipe GenAI doesn't support concurrent generation requests. Wait for one rewrite to complete before starting another.

- **Model Quality**: Local models may have lower quality than cloud APIs like Gemini, but they work offline and don't require API keys.

- **Platform Support**: Currently supports macOS. Windows and Linux support coming soon.

- **Model Availability**: Models must be obtained from Kaggle and self-hosted. The app doesn't include models by default.

## Advanced Configuration

### Custom Model Path

You can specify a custom path to a model file programmatically, but the easiest way is to place it in `~/Downloads` or configure a URL in settings.

### Model Parameters

The app uses these default parameters:
- `maxTokens: 512` - Maximum tokens to generate
- `temperature: 0.7` - Controls randomness (0.0-1.0)
- `topK: 40` - Top-K sampling parameter

These are optimized for text rewriting tasks. Advanced users can modify these in `lib/core/services/local_ai_service.dart`.

## Additional Resources

- [MediaPipe GenAI Documentation](https://pub.dev/documentation/mediapipe_genai/latest/)
- [MediaPipe Website](https://mediapipe.dev/)
- [Kaggle Models](https://www.kaggle.com/models)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review app logs for detailed error messages
3. Ensure all prerequisites are met
4. Try switching to Gemini API as a fallback

