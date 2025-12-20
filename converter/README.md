# Model Converter

Convert Mediapipe-compatible models from SafeTensors format to Mediapipe Task format for use in Flutter apps.

## Quick Start

### Prerequisites

1. **Mediapipe Source Code**: Clone the Mediapipe repository
   ```bash
   git clone https://github.com/google/mediapipe.git
   export MEDIAPIPE_PATH=/path/to/mediapipe
   ```

2. **Python Dependencies**: Install required packages
   ```bash
   pip install sentencepiece jax jaxlib
   ```

### Basic Usage

```bash
# Convert a Gemma model
MODEL_PATH=/path/to/model MODEL_TYPE=GEMMA3_300M python convert_model.py
```

### Supported Model Types

- `GEMMA3_300M` - Gemma 3 300M models
- `GEMMA3_1B` - Gemma 3 1B models
- `GEMMA3_4B` - Gemma 3 4B models
- `GEMMA3_12B` - Gemma 3 12B models
- `GEMMA3_27B` - Gemma 3 27B models
- `GEMMA_2B` - Gemma 2B models
- `GEMMA2_2B` - Gemma 2 2B models

### Environment Variables

- `MODEL_PATH`: Path to the HuggingFace model directory (default: FunctionGemma-270M)
- `MODEL_TYPE`: Model type identifier (default: GEMMA3_300M)
- `MEDIAPIPE_PATH`: Path to Mediapipe source code (default: /Users/bw/abhishekthakur/mediapipe)

### Output

The converter creates a `.task` file in `assets/models/model.task` that can be used directly in your Flutter app.

## Troubleshooting

### Mediapipe Source Not Found

Ensure you have the Mediapipe source code cloned and update `MEDIAPIPE_PATH` in the script or set it as an environment variable.

### Missing Dependencies

Install required Python packages:
```bash
pip install sentencepiece jax jaxlib torch
```

### Conversion Errors

1. Check that your model directory contains:
   - `model.safetensors` or `*.safetensors` files
   - `tokenizer.model` or `tokenizer.json` + `tokenizer_config.json`

2. Verify the `MODEL_TYPE` matches your model architecture

3. Ensure you have enough disk space (conversion can require 5-10GB)

## Integration with Flutter

After conversion:

1. Move the `.task` file to `assets/models/`
2. Update `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/models/your_model.task
   ```
3. Run `flutter pub get`
4. The model will be automatically loaded by `LocalAIService`
