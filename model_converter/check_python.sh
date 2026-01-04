#!/bin/bash
# Helper script to check Python version and find Python 3.10+

echo "🔍 Checking for Python 3.10+ installation..."
echo ""

# Check for various Python versions
FOUND_PYTHON=""

for version in python3.12 python3.11 python3.10 python3; do
    if command -v "$version" &> /dev/null; then
        PYTHON_VERSION=$($version --version 2>&1 | cut -d' ' -f2)
        PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1,2)
        
        echo "Found: $version -> $PYTHON_VERSION"
        
        # Check if version is 3.10 or higher
        if [ "$(printf '%s\n' "3.10" "$PYTHON_MAJOR_MINOR" | sort -V | head -n1)" = "3.10" ] || [ "$PYTHON_MAJOR_MINOR" = "3.10" ]; then
            if [ -z "$FOUND_PYTHON" ]; then
                FOUND_PYTHON="$version"
            fi
        fi
    fi
done

echo ""

if [ -n "$FOUND_PYTHON" ]; then
    echo "✅ Found compatible Python: $FOUND_PYTHON"
    echo ""
    echo "💡 To use this version for setup:"
    echo "   $FOUND_PYTHON -m venv venv"
    echo "   source venv/bin/activate"
    echo "   pip install -r requirements.txt"
    exit 0
else
    echo "❌ No Python 3.10+ found"
    echo ""
    echo "💡 To install Python 3.10+ on macOS:"
    echo ""
    echo "Option 1: Using Homebrew"
    echo "   brew install python@3.10"
    echo ""
    echo "Option 2: Using pyenv"
    echo "   brew install pyenv"
    echo "   pyenv install 3.10"
    echo "   pyenv local 3.10"
    echo ""
    echo "Option 3: Download from python.org"
    echo "   Visit: https://www.python.org/downloads/"
    exit 1
fi

