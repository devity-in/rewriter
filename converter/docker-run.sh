#!/bin/bash
# Docker run script for Phi-3 converter

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODEL_DIR="/Users/bw/abhishekthakur/Phi-3-mini-4k-instruct"

echo "Phi-3 Mini Converter - Docker"
echo "=============================="
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
echo ""

# Build the Docker image
echo "Building Docker image..."
cd "$SCRIPT_DIR"
docker build -t phi3-converter:latest .

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

docker run --rm -it \
    -v "$PROJECT_ROOT:/workspace" \
    -v "$MODEL_DIR:/model:ro" \
    -w /workspace/converter \
    phi3-converter:latest \
    python convert_phi3.py

if [ $? -eq 0 ]; then
    echo ""
    echo "=============================="
    echo "✓ Conversion complete!"
    echo "=============================="
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
    echo "=============================="
    echo "✗ Conversion failed"
    echo "=============================="
    echo ""
    echo "Check the error messages above for details"
    exit 1
fi
