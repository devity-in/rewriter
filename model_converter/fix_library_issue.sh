#!/bin/bash
# Script to fix ai-edge-torch library loading issues on macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Virtual environment not found. Run ./setup_env.sh first."
    exit 1
fi

echo "🔧 Fixing ai-edge-torch library loading issues..."
echo ""

source "$VENV_DIR/bin/activate"

echo "📦 Step 1: Uninstalling ai-edge-torch and related packages..."
pip uninstall -y ai-edge-torch ai-edge-litert ai-edge-quantizer ai-edge-tensorflow 2>/dev/null || true

echo ""
echo "📥 Step 2: Reinstalling ai-edge-torch (this may take a few minutes)..."
pip install --no-cache-dir 'ai-edge-torch>=0.6.0'

echo ""
echo "✅ Reinstallation complete!"
echo ""
echo "🧪 Testing import..."
if python -c "from ai_edge_torch.generative.examples import gemma3; print('✅ Import successful!')" 2>&1; then
    echo ""
    echo "✅ Library loading issue appears to be fixed!"
else
    echo ""
    echo "⚠️  Library loading issue persists."
    echo ""
    echo "💡 Additional troubleshooting steps:"
    echo "   1. Check Python version: python --version (should be 3.10+)"
    echo "   2. Try installing tensorflow-lite-runtime: pip install tensorflow-lite-runtime"
    echo "   3. Check ai-edge-torch GitHub issues for macOS-specific fixes"
    echo "   4. Consider using a conda environment instead of venv"
fi

