#!/bin/bash
# Run the Mediapipe model converter directly on macOS (no Docker)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Mediapipe Model Converter - Direct (No Docker)"
echo "==========================================="
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Running setup..."
    ./setup.sh
fi

# Activate virtual environment
source venv/bin/activate

# Check for required dependencies
echo "Checking dependencies..."
python3 -c "import torch; import jax; import sentencepiece; print('✓ All dependencies available')" 2>/dev/null || {
    echo "Installing missing dependencies..."
    pip install sentencepiece jax jaxlib
}

# Get model path and type from environment or prompt
MODEL_PATH="${MODEL_PATH:-}"
MODEL_TYPE="${MODEL_TYPE:-GEMMA3_300M}"

if [ -z "$MODEL_PATH" ]; then
    echo ""
    echo "Model path not set. Using default FunctionGemma-270M model."
    echo "To specify a custom model:"
    echo "  MODEL_PATH=/path/to/model MODEL_TYPE=GEMMA3_300M ./run_converter.sh"
    echo ""
    MODEL_PATH="/Users/bw/.cache/huggingface/hub/models--google--functiongemma-270m-it/snapshots/ead2a1f9df8d6431408ccff6c9e5e60028addde0"
fi

# Run the converter
echo ""
echo "Running converter..."
echo "Model Path: $MODEL_PATH"
echo "Model Type: $MODEL_TYPE"
echo "This will take 10-20 minutes..."
echo ""

MODEL_PATH="$MODEL_PATH" MODEL_TYPE="$MODEL_TYPE" python3 convert_model.py

if [ $? -eq 0 ]; then
    echo ""
    echo "==========================================="
    echo "✓ Conversion complete!"
    echo "==========================================="
    echo ""
    echo "Output file: ../assets/models/model.task"
    echo ""
    echo "Next steps:"
    echo "1. Rename the output file if needed"
    echo "2. Update pubspec.yaml to include:"
    echo "   assets:"
    echo "     - assets/models/your_model.task"
    echo "3. Run: flutter pub get"
    echo "4. Restart your app"
else
    echo ""
    echo "==========================================="
    echo "✗ Conversion failed"
    echo "==========================================="
    echo ""
    echo "Check the error messages above for details"
    exit 1
fi
