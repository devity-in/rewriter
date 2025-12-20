#!/bin/bash
# Setup script for Mediapipe model converter

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Setting up Mediapipe Model Converter..."
echo "========================================"
echo ""

# Check for Python 3.10+
PYTHON_CMD=""
if command -v python3.10 &> /dev/null; then
    PYTHON_CMD="python3.10"
elif command -v python3.11 &> /dev/null; then
    PYTHON_CMD="python3.11"
elif command -v python3.12 &> /dev/null; then
    PYTHON_CMD="python3.12"
elif command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    
    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 10 ]; then
        PYTHON_CMD="python3"
    fi
fi

if [ -z "$PYTHON_CMD" ]; then
    echo "ERROR: Python 3.10+ is required but not found."
    echo ""
    echo "Please install Python 3.10 or later:"
    echo "  macOS: brew install python@3.10"
    echo "  Linux: sudo apt-get install python3.10"
    echo ""
    exit 1
fi

echo "Using Python: $PYTHON_CMD"
$PYTHON_CMD --version
echo ""

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv venv
    echo "✓ Virtual environment created"
else
    echo "Virtual environment already exists"
fi

# Activate virtual environment
echo ""
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip > /dev/null 2>&1

# Install dependencies
echo ""
echo "Installing dependencies..."
pip install -q sentencepiece jax jaxlib

echo ""
echo "========================================"
echo "✓ Setup complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Ensure Mediapipe source code is available"
echo "  2. Run: ./run_converter.sh"
echo "     Or: MODEL_PATH=/path/to/model MODEL_TYPE=GEMMA3_300M python convert_model.py"
