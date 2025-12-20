#!/bin/bash
# Docker run script for Phi-3 converter using Mediapipe safetensors converter

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODEL_DIR="/Users/bw/abhishekthakur/Phi-3-mini-4k-instruct"
MEDIAPIPE_DIR="/Users/bw/abhishekthakur/mediapipe"

echo "Phi-3 Mini Converter - Mediapipe (Docker)"
echo "=========================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    echo "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "ERROR: Docker is not running"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

# Check if model directory exists
if [ ! -d "$MODEL_DIR" ]; then
    echo "ERROR: Model directory not found: $MODEL_DIR"
    echo "Please update MODEL_DIR in this script to point to your Phi-3 model directory"
    exit 1
fi

echo "Project root: $PROJECT_ROOT"
echo "Model directory: $MODEL_DIR"
if [ -d "$MEDIAPIPE_DIR" ]; then
    echo "Mediapipe source directory: $MEDIAPIPE_DIR (optional, will use installed package if not found)"
else
    echo "Mediapipe: Will use installed package"
fi
echo ""

# Build the Docker image
echo "Building Docker image..."
cd "$SCRIPT_DIR"
docker build -f Dockerfile.mediapipe -t phi3-converter-mediapipe:latest . 2>&1 | grep -E "(Step|Successfully|ERROR)" || true

if [ $? -ne 0 ]; then
    echo "ERROR: Docker build failed"
    exit 1
fi

echo ""
echo "✓ Docker image built successfully"
echo ""

# Run the converter
echo "Running converter..."
echo "This will take 20-30 minutes..."
echo ""

# Build volume mount command
VOLUME_MOUNTS="-v $PROJECT_ROOT:/workspace -v $MODEL_DIR:/model:ro"
if [ -d "$MEDIAPIPE_DIR" ]; then
    VOLUME_MOUNTS="$VOLUME_MOUNTS -v $MEDIAPIPE_DIR:/mediapipe:ro -e MEDIAPIPE_PATH=/mediapipe"
fi

docker run --rm -it \
    $VOLUME_MOUNTS \
    -e MODEL_PATH=/model \
    -w /workspace/converter \
    phi3-converter-mediapipe:latest \
    python convert_phi3_mediapipe.py

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Conversion complete!"
    echo "=========================================="
    echo ""
    echo "Output file: $PROJECT_ROOT/assets/models/phi3_mini.task"
    echo ""
    echo "Next steps:"
    echo "1. Update pubspec.yaml to include:"
    echo "   assets:"
    echo "     - assets/models/phi3_mini.task"
    echo "2. Run: flutter pub get"
    echo "3. Restart your app"
else
    echo ""
    echo "=========================================="
    echo "✗ Conversion failed"
    echo "=========================================="
    echo ""
    echo "Check the error messages above for details"
    exit 1
fi
