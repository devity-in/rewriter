#!/bin/bash
# Quick test to verify Docker setup

echo "Testing Docker setup..."
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker Desktop."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker not running. Please start Docker Desktop."
    exit 1
fi

echo "✅ Docker is installed and running"
echo ""

# Check files
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found"
    exit 1
fi

if [ ! -f "convert_phi3.py" ]; then
    echo "❌ convert_phi3.py not found"
    exit 1
fi

if [ ! -f "requirements.txt" ]; then
    echo "❌ requirements.txt not found"
    exit 1
fi

echo "✅ All required files present"
echo ""
echo "Ready to run: ./docker-run.sh"
