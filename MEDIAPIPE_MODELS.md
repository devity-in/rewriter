# MediaPipe GenAI Compatible Models

## Supported Models

MediaPipe GenAI works with models in `.task` format (MediaPipe Task format). Based on the official examples and documentation, here are the compatible models:

### Gemma Models (Primary)

**From the example app, these are the officially supported models:**

1. **Gemma 4b CPU** (4-bit quantization, CPU optimized)
   - Format: `.task`
   - Hardware: CPU
   - Use case: Smaller, faster inference on CPU-only devices

2. **Gemma 4b GPU** (4-bit quantization, GPU optimized)
   - Format: `.task`
   - Hardware: GPU (Metal on macOS, Vulkan/OpenGL on other platforms)
   - Use case: Faster inference with GPU acceleration

3. **Gemma 8b CPU** (8-bit quantization, CPU optimized)
   - Format: `.task`
   - Hardware: CPU
   - Use case: Better quality than 4-bit, slower than GPU

4. **Gemma 8b GPU** (8-bit quantization, GPU optimized)
   - Format: `.task`
   - Hardware: GPU
   - Use case: Best quality, requires GPU support

### Other Compatible Models

From web search and documentation:

- **Gemma 2B** - TensorFlow Lite formats (2b-it-gpu-int4, 2b-it-gpu-int8)
- **Gemma 7B** - TensorFlow Lite format (7b-it-gpu-int8)
- **Gemma 3n E2B** - For Android devices
- **Gemma 3n E4B** - For Android devices
- **functiongemma_270m** - Smaller, faster model (mentioned in LOCAL_AI_SETUP.md)
- **gemma_2b** - Larger, better quality model (mentioned in LOCAL_AI_SETUP.md)

**Note**: Only GPU-encoded models are currently supported for some platforms. CPU models are available for certain configurations.

## Model Format Requirements

### Required Format
- **File extension**: `.task` (MediaPipe Task format)
- **Not supported**: Raw `.bin`, `.safetensors`, or `.tflite` files directly
- **Conversion needed**: Models from Hugging Face must be converted using the conversion script

### Conversion Process

Models need to be converted from Hugging Face format to MediaPipe `.task` format:

1. **Source**: Hugging Face Safetensors (`.safetensors`)
2. **Tool**: Use `model_converter/convert_hf_to_mediapipe.py`
3. **Output**: MediaPipe Task format (`.task`)

See: `model_converter/convert_hf_to_mediapipe.py` for conversion instructions.

## Where to Get Models

### Option 1: Kaggle (Recommended for Pre-converted Models)

1. Visit [Kaggle.com](https://www.kaggle.com)
2. Search for "MediaPipe GenAI" or "Gemma MediaPipe"
3. Look for datasets with `.task` files
4. Download directly or use Kaggle API

**Note**: You may need a Kaggle account and API credentials to download.

### Option 2: Convert from Hugging Face

1. Download Gemma models from Hugging Face:
   - `google/gemma-2b-it`
   - `google/gemma-7b-it`
   - `google/gemma-3-270m-it` (for functiongemma_270m)

2. Use the conversion script:
   ```bash
   python model_converter/convert_hf_to_mediapipe.py \
       --input /path/to/huggingface/model \
       --output /path/to/output.model.task \
       --architecture gemma2  # or gemma3
   ```

### Option 3: Official MediaPipe Releases

Check the MediaPipe GitHub repository or official documentation for pre-converted model releases.

## Model Selection Guide

### For macOS (Your Current Platform)

**Recommended**: Start with **Gemma 4b GPU** or **Gemma 8b GPU**
- macOS has Metal GPU support
- GPU models are faster
- 8b provides better quality than 4b

**If GPU not available**: Use **Gemma 4b CPU** or **Gemma 8b CPU**
- Fallback option
- Slower but still functional

### For Testing/Development

**Start with**: **functiongemma_270m** or **Gemma 4b CPU**
- Smaller file size
- Faster downloads
- Good enough for testing functionality

### For Production

**Recommended**: **Gemma 8b GPU** or **Gemma 7b GPU**
- Best quality output
- Reasonable speed with GPU
- Good balance of quality and performance

## Model URLs and Configuration

Models can be configured via:
1. **Environment variables** (macOS/Linux):
   ```bash
   export GEMMA_8B_GPU_URI=https://your-server.com/gemma-8b-gpu.task
   ```

2. **Dart defines** (All platforms):
   ```bash
   flutter run --dart-define=GEMMA_8B_GPU_URI=https://your-server.com/gemma-8b-gpu.task
   ```

3. **App settings** (Your current implementation):
   - Configure model URL in app settings
   - App downloads and caches automatically

## Model Size Estimates

Based on typical quantization:
- **270M models**: ~100-200 MB
- **2B models**: ~1-2 GB
- **4B models**: ~2-4 GB
- **7B-8B models**: ~4-8 GB

**Note**: Actual sizes vary based on quantization method and model variant.

## Next Steps

1. **Choose a model**: Start with Gemma 4b GPU for macOS
2. **Obtain the model**: 
   - Download from Kaggle, OR
   - Convert from Hugging Face using the converter script
3. **Host the model**: 
   - Self-host on a web server, OR
   - Use local server for development (`scripts/serve_models.sh`)
4. **Configure in app**: Enter model URL in settings

## References

- Official MediaPipe GenAI docs: https://ai.google.dev/gemma/docs/conversions/hf-to-mediapipe-task
- Example app: `example/` directory in this project
- Conversion script: `model_converter/convert_hf_to_mediapipe.py`
- Setup guide: `LOCAL_AI_SETUP.md`

