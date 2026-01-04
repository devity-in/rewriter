#!/bin/bash
# Setup script for Python virtual environment

# Don't exit on error immediately - we want to check for Python versions
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

echo "🔧 Setting up Python virtual environment for model converter..."
echo ""

# Find the best Python 3.10+ version first
PYTHON_CMD=""
PYTHON_VERSION_FOUND=""

echo "🔍 Searching for Python 3.10+..."

# Check each version in order of preference
for version in python3.12 python3.11 python3.10; do
    # First check if it's in PATH
    path=$(command -v "$version" 2>/dev/null)
    if [ -n "$path" ] && [ -x "$path" ]; then
        ver_output=$("$path" --version 2>&1)
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            found_version=$(echo "$ver_output" | cut -d' ' -f2)
            major_minor=$(echo "$found_version" | cut -d'.' -f1,2)
            
            # Check if version is 3.10 or higher (simplified check)
            if [ "$major_minor" = "3.10" ] || [ "$major_minor" = "3.11" ] || [ "$major_minor" = "3.12" ] || [ "$major_minor" = "3.13" ]; then
                PYTHON_CMD="$path"
                PYTHON_VERSION_FOUND="$found_version"
                echo "   ✅ Found: $path (Python $found_version)"
                break
            fi
        fi
    fi
    
    # Check common installation directories
    for base_dir in "/opt/homebrew/bin" "/usr/local/bin" "/opt/local/bin"; do
        test_path="$base_dir/$version"
        if [ -x "$test_path" ] 2>/dev/null; then
            ver_output=$("$test_path" --version 2>&1)
            exit_code=$?
            if [ $exit_code -eq 0 ]; then
                found_version=$(echo "$ver_output" | cut -d' ' -f2)
                major_minor=$(echo "$found_version" | cut -d'.' -f1,2)
                
                # Check if version is 3.10 or higher (simplified check)
                if [ "$major_minor" = "3.10" ] || [ "$major_minor" = "3.11" ] || [ "$major_minor" = "3.12" ] || [ "$major_minor" = "3.13" ]; then
                    PYTHON_CMD="$test_path"
                    PYTHON_VERSION_FOUND="$found_version"
                    echo "   ✅ Found: $test_path (Python $found_version)"
                    break 2
                fi
            fi
        fi
    done
done

# Re-enable exit on error for the rest of the script
set -e

# If no Python 3.10+ found, check default python3 and show error
if [ -z "$PYTHON_CMD" ]; then
    echo "   ⚠️  No Python 3.10+ found in common locations"
    echo ""
    
    # Check what python3 we have
    if command -v python3 &> /dev/null; then
        DEFAULT_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
        echo "   Found default python3: Python $DEFAULT_VERSION"
    fi
    
    echo ""
    echo "❌ Error: Python 3.10 or higher is required"
    echo ""
    echo "💡 To install Python 3.10+ on macOS:"
    echo "   1. Install via Homebrew: brew install python@3.10"
    echo "   2. Or use pyenv: brew install pyenv && pyenv install 3.10"
    echo ""
    echo "   After installing, run this script again."
    exit 1
fi

echo ""
echo "✅ Using Python: $PYTHON_CMD (Python $PYTHON_VERSION_FOUND)"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo ""
    echo "📦 Creating virtual environment..."
    "$PYTHON_CMD" -m venv "$VENV_DIR"
    echo "✅ Virtual environment created with Python $PYTHON_VERSION_FOUND"
else
    echo ""
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
echo ""
echo "🔌 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo ""
echo "⬆️  Upgrading pip..."
pip install --upgrade pip > /dev/null 2>&1

# Install requirements
echo ""
echo "📥 Installing requirements..."
pip install -r "$SCRIPT_DIR/requirements.txt"

echo ""
echo "✅ Setup complete!"
echo ""
echo "💡 To use the converter:"
echo "   1. Activate the environment: source venv/bin/activate"
echo "   2. Run the converter: python convert_hf_to_mediapipe.py --help"
echo ""
echo "   Or use the convenience script: ./convert.sh"

