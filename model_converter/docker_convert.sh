#!/bin/bash
# Docker-based converter script (workaround for macOS ARM64 issues)
# Uses a lightweight Linux container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="model-converter"
CONTAINER_NAME="model-converter-$$"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed"
    echo "   Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to build image if needed
build_image() {
    # Check if image exists and is for the correct platform
    if docker image inspect "$IMAGE_NAME:latest" &> /dev/null; then
        ARCH=$(docker image inspect "$IMAGE_NAME:latest" --format '{{.Architecture}}' 2>/dev/null || echo "")
        if [ "$ARCH" = "amd64" ]; then
            echo -e "${GREEN}✅ Docker image already exists (amd64 platform)${NC}"
            return 0
        else
            echo -e "${BLUE}⚠️  Existing image is for $ARCH platform, rebuilding for amd64...${NC}"
        fi
    fi
    
    echo -e "${BLUE}🐳 Building lightweight Docker image (linux/amd64 platform)...${NC}"
    echo -e "${BLUE}   Note: Using amd64 platform for compatibility with ai-edge-tensorflow${NC}"
    echo -e "${BLUE}   This may take several minutes on first build...${NC}"
    docker build --platform linux/amd64 -t "$IMAGE_NAME:latest" "$SCRIPT_DIR"
    echo -e "${GREEN}✅ Docker image built successfully!${NC}"
}

# Build image
build_image

# If no arguments provided, show usage
if [ $# -eq 0 ]; then
    echo ""
    echo "Usage:"
    echo "  $0 --input <input_path> --output <output_path> [other_options]"
    echo ""
    echo "Example:"
    echo "  $0 --input ../models/your-model --output ../models/output.task"
    echo ""
    echo "The input and output paths should be relative to the project root (../models/)"
    echo "or absolute paths. They will be mounted into the container."
    exit 0
fi

# Resolve paths
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_DIR="$PROJECT_ROOT/models"

# Ensure models directory exists
mkdir -p "$MODELS_DIR"

echo ""
echo -e "${BLUE}🚀 Running converter in Docker container...${NC}"
echo ""

# Run the converter in Docker
# Mount the models directory and the converter script
# Try with platform first, fallback to without if local image doesn't match
if docker run --rm --platform linux/amd64 --pull=never "$IMAGE_NAME:latest" python --version &>/dev/null; then
    PLATFORM_FLAG="--platform linux/amd64"
else
    # If platform flag doesn't work, try without it (use local image as-is)
    echo -e "${BLUE}   Using local image without platform specification...${NC}"
    PLATFORM_FLAG=""
fi

docker run --rm \
    $PLATFORM_FLAG \
    --pull=never \
    --name "$CONTAINER_NAME" \
    -v "$MODELS_DIR:/models" \
    -v "$SCRIPT_DIR/convert_hf_to_mediapipe.py:/app/convert_hf_to_mediapipe.py" \
    "$IMAGE_NAME:latest" \
    python convert_hf_to_mediapipe.py "$@"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Conversion completed successfully!${NC}"
else
    echo ""
    echo "❌ Conversion failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi

