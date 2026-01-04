#!/bin/bash

# Simple wrapper script to run the Python model server
# This makes it easier to start the server without typing python3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
PORT=8000
DIRECTORY="$PROJECT_ROOT/models"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --directory)
            DIRECTORY="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--port PORT] [--directory DIR]"
            echo ""
            echo "Options:"
            echo "  --port PORT      Port to serve on (default: 8000)"
            echo "  --directory DIR  Directory to serve from (default: ./models)"
            echo ""
            echo "Examples:"
            echo "  $0                          # Serve on port 8000 from ./models"
            echo "  $0 --port 8080              # Serve on port 8080"
            echo "  $0 --directory ~/my_models  # Serve from custom directory"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed or not in PATH"
    echo "Please install Python 3 first"
    exit 1
fi

# Run the Python server
cd "$PROJECT_ROOT"
python3 "$SCRIPT_DIR/serve_models.py" --port "$PORT" --directory "$DIRECTORY"

