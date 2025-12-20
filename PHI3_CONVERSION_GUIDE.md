# Converting Phi-3 Mini from SafeTensors to Mediapipe Task Format

You have downloaded the Phi-3 Mini model in SafeTensors format, but Mediapipe GenAI requires the `.task` format. Follow these steps to convert it:

## Prerequisites

1. **Python 3.8+** installed
2. **pip** package manager

## Step 1: Install AI Edge Torch Converter

```bash
# Create a virtual environment (recommended)
python -m venv ai-edge-torch
source ai-edge-torch/bin/activate  # On macOS/Linux
# or
ai-edge-torch\Scripts\activate  # On Windows

# Install the converter
pip install "ai-edge-torch>=0.6.0"
```

## Step 2: Convert SafeTensors to TFLite

Create a Python script `convert_phi3.py`:

```python
from ai_edge_torch.generative.examples.phi3 import phi3
from ai_edge_torch.generative.utilities import converter
from ai_edge_torch.generative.utilities.export_config import ExportConfig
from ai_edge_torch.generative.layers import kv_cache

# Path to your downloaded model directory
HF_MODEL_PATH = "/Users/bw/abhishekthakur/Phi-3-mini-4k-instruct"
OUTPUT_DIR = "/Users/bw/abhishekthakur/phi3_converted"

# Load the Phi-3 model
print("Loading Phi-3 model...")
pytorch_model = phi3.build_model(HF_MODEL_PATH)

# Configure export settings
export_config = ExportConfig()
export_config.kvcache_layout = kv_cache.KV_LAYOUT_TRANSPOSED
export_config.mask_as_input = True

# Convert to TFLite
print("Converting to TFLite format...")
converter.convert_to_tflite(
    pytorch_model,
    output_path=OUTPUT_DIR,
    output_name_prefix="phi3-mini",
    prefill_seq_len=2048,
    kv_cache_max_len=4096,
    quantize="dynamic_int8",  # Use int8 quantization for smaller size
    export_config=export_config,
)

print(f"Conversion complete! Check {OUTPUT_DIR} for the TFLite file.")
```

Run the script:
```bash
python convert_phi3.py
```

## Step 3: Convert TFLite to Mediapipe Task Format

Install MediaPipe:
```bash
pip install mediapipe
```

Create a conversion script `convert_to_task.py`:

```python
import mediapipe as mp
from mediapipe.tasks.python.genai import converter

def phi3_convert_config(backend='cpu'):
    # Paths - adjust these to match your setup
    input_tflite = '/Users/bw/abhishekthakur/phi3_converted/phi3-mini.tflite'
    vocab_model_file = '/Users/bw/abhishekthakur/Phi-3-mini-4k-instruct/tokenizer.model'  # If available
    output_dir = '/Users/bw/abhishekthakur/phi3_converted/intermediate'
    output_task_file = '/Users/bw/abhishekthakur/phi3_converted/phi3_mini.task'
    
    return converter.ConversionConfig(
        input_ckpt=input_tflite,
        ckpt_format='tflite',
        model_type='PHI_3',
        backend=backend,
        output_dir=output_dir,
        combine_file_only=False,
        vocab_model_file=vocab_model_file if vocab_model_file else None,
        output_tflite_file=output_task_file
    )

# Convert for CPU backend
print("Converting to Mediapipe Task format...")
config = phi3_convert_config(backend='cpu')
converter.convert(config)
print(f"Conversion complete! Task file: {config.output_tflite_file}")
```

Run the script:
```bash
python convert_to_task.py
```

## Step 4: Add Model to Flutter App

1. Copy the converted `.task` file to your Flutter project:
   ```bash
   mkdir -p /Users/bw/abhishekthakur/rewriter/assets/models
   cp /Users/bw/abhishekthakur/phi3_converted/phi3_mini.task /Users/bw/abhishekthakur/rewriter/assets/models/
   ```

2. Update `pubspec.yaml` to include the asset:
   ```yaml
   flutter:
     assets:
       - assets/models/phi3_mini.task
   ```

3. Run `flutter pub get` to update assets

## Alternative: Download Pre-converted Model

If conversion is too complex, you can download a pre-converted `.task` file from:
- Google AI Edge Model Gallery (if available)
- Community repositories (verify compatibility)

## Troubleshooting

- **Missing tokenizer.model**: The tokenizer file might be in a different location. Check the HuggingFace model repository for tokenizer files.
- **Memory errors**: Reduce `prefill_seq_len` and `kv_cache_max_len` values
- **Conversion fails**: Ensure you have enough disk space (conversion can require 10GB+)

## Notes

- The conversion process can take 30+ minutes depending on your hardware
- The converted `.task` file will be smaller than the original SafeTensors files due to quantization
- Make sure the model path in the Flutter app matches the actual file location
