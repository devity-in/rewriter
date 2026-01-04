# Model Converter

Convert Hugging Face models to MediaPipe GenAI `.task` format for use with the Rewriter app.

## Overview

This converter takes unzipped Hugging Face model files (Safetensors, config.json, tokenizer.model) and converts them into MediaPipe GenAI `.task` files that can be used for on-device inference.

## Quick Start

### 0. Check Python Version (Optional)

```bash
# Check if you have Python 3.10+ installed
./check_python.sh
```

### 1. Setup Python Environment

```bash
# Run the setup script
./setup_env.sh
```

This will:
- Check for Python 3.10+ (required)
- Create a Python virtual environment
- Install all required dependencies (`ai-edge-torch`, `mediapipe`)

**Note**: If you get an error about Python version, see the [Requirements](#requirements) section below for upgrade instructions.

### 2. Convert a Model

**Option A: Native Python (Linux or macOS with working ai-edge-torch)**

```bash
# Activate the environment
source venv/bin/activate

# Run the converter
python convert_hf_to_mediapipe.py \
    --input ../models/your-model-directory \
    --output ../models/output.task
```

Or use the convenience script:

```bash
./convert.sh \
    --input ../models/your-model-directory \
    --output ../models/output.task
```

**Option B: Docker (Recommended for macOS ARM64)**

If you're on macOS and encounter library loading issues, use Docker:

```bash
# Build the lightweight Docker image (first time only)
docker build -t model-converter:latest .

# Run the converter
./docker_convert.sh \
    --input ../models/your-model-directory \
    --output ../models/output.task
```

The Docker image uses a multi-stage build for minimal size (~500MB-1GB including dependencies).

## Requirements

- **Python 3.10 or higher** (required by `ai-edge-torch>=0.6.0`)
- Virtual environment (created automatically by `setup_env.sh`)

### Installing Python 3.10+ on macOS

If you have Python 3.9 or earlier, you'll need to upgrade:

**Option 1: Using Homebrew**
```bash
brew install python@3.10
# Then use python3.10 instead of python3
python3.10 -m venv venv
```

**Option 2: Using pyenv**
```bash
brew install pyenv
pyenv install 3.10
pyenv local 3.10
```

**Option 3: Download from python.org**
- Visit https://www.python.org/downloads/
- Download Python 3.10 or later for macOS

## Supported Models

- **Gemma 2**: 270M, 2B, 7B
- **Gemma 3**: 270M, 2B, 7B

The script can auto-detect the model architecture and size from `config.json`, or you can specify them manually.

## Usage

### Basic Usage (Auto-detection)

```bash
python convert_hf_to_mediapipe.py \
    --input ../models/qwen2-transformers-0.5b-v1 \
    --output ../models/qwen2_0.5b.task
```

### With Explicit Architecture

```bash
python convert_hf_to_mediapipe.py \
    --input ../models/gemma-3-2b \
    --output ../models/gemma_3_2b.task \
    --architecture gemma3 \
    --size 2b
```

### Advanced Options

```bash
python convert_hf_to_mediapipe.py \
    --input ../models/gemma-2-270m \
    --output ../models/gemma_2_270m.task \
    --temp ./temp/tflite_output \
    --prefill-seq-len 2048 \
    --kv-cache-max-len 4096
```

## Command-Line Options

- `--input`: Path to directory containing Hugging Face model files (required)
- `--output`: Output path for the final `.task` file (required)
- `--temp`: Temporary directory for intermediate `.tflite` file (optional, uses system temp by default)
- `--tokenizer`: Path to tokenizer.model file (optional, defaults to `<input>/tokenizer.model`)
- `--architecture`: Model architecture (`gemma2` or `gemma3`) - auto-detected if not specified
- `--size`: Model size (`270m`, `2b`, `7b`) - auto-detected if not specified
- `--prefill-seq-len`: Prefill sequence length (default: 2048)
- `--kv-cache-max-len`: KV cache max length (default: 4096)
- `--model-name-prefix`: Prefix for the tflite file name (default: `<architecture>_<size>`)

## Input Requirements

The input directory must contain:

- `config.json` - Model configuration file (required)
- `*.safetensors` or `*.bin` - Model weights (at least one required)
- `tokenizer.model` or `tokenizer.json` - Tokenizer file (required)

## Conversion Process

The converter performs three main steps:

1. **Load Model**: Uses `ai_edge_torch.generative` to load the model architecture
2. **Convert to TFLite**: Converts to LiteRT format with `dynamic_int8` quantization
3. **Package**: Uses `mediapipe.tasks.python.genai.bundler` to create the final `.task` file

## Output

The converter creates a `.task` file that can be:

1. Used with the `serve_models.py` script
2. Placed in the `models/` directory
3. Configured in the app: Settings → Local AI Model

## Troubleshooting

### Virtual Environment Issues

If you encounter issues with the virtual environment:

```bash
# Remove and recreate
rm -rf venv
./setup_env.sh
```

### Missing Dependencies

If you get import errors:

```bash
source venv/bin/activate
pip install -r requirements.txt
```

### Library Loading Issues (macOS ARM64)

If you encounter errors like `Library not loaded: libpywrap_litert_common.dylib`:

**This is a known packaging issue with `ai-edge-torch` on macOS ARM64.** The macOS wheel is missing required dynamic libraries.

**Recommended Solution: Use Docker**

```bash
# Build and run using Docker (works around macOS issues)
./docker_convert.sh --input ../models/your-model --output ../models/output.task
```

**Alternative: Try fixing native installation**

```bash
# Run the fix script
./fix_library_issue.sh

# Or manually reinstall
source venv/bin/activate
pip uninstall -y ai-edge-torch ai-edge-litert
pip install --no-cache-dir 'ai-edge-torch>=0.6.0'
```

**Why Docker works**: The Linux wheels are properly packaged with all required libraries, while the macOS ARM64 wheel has packaging issues. Docker runs Linux in a container, avoiding the macOS-specific problems.

### Model Detection Issues

If auto-detection fails, specify the architecture and size manually:

```bash
python convert_hf_to_mediapipe.py \
    --input ../models/your-model \
    --output ../models/output.task \
    --architecture gemma3 \
    --size 270m
```

## Files

- `convert_hf_to_mediapipe.py` - Main converter script
- `requirements.txt` - Python dependencies
- `setup_env.sh` - Environment setup script
- `convert.sh` - Convenience wrapper script (native Python)
- `docker_convert.sh` - Docker-based converter script (macOS workaround)
- `Dockerfile` - Lightweight multi-stage Docker image
- `.dockerignore` - Files to exclude from Docker build
- `fix_library_issue.sh` - Script to fix library loading issues on macOS
- `check_python.sh` - Helper script to check Python version
- `README.md` - This file

## Notes

- Conversion can take several minutes for larger models
- Temporary files are cleaned up automatically (unless `--temp` is specified)
- The converter requires significant disk space for intermediate files
- GPU acceleration is recommended for faster conversion

