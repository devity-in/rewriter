#!/bin/bash
# Convenience script to run the converter with the virtual environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Virtual environment not found"
    echo "   Please run: ./setup_env.sh"
    exit 1
fi

# Activate virtual environment and run the converter
source "$VENV_DIR/bin/activate"
python "$SCRIPT_DIR/convert_hf_to_mediapipe.py" "$@"

