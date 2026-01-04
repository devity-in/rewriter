# Lightweight Docker image for model converter
# Multi-stage build to minimize final image size
# Note: Uses linux/amd64 platform for compatibility (ai-edge-tensorflow has no ARM64 Linux wheels)

# Stage 1: Build stage (includes build tools)
FROM --platform=linux/amd64 python:3.10-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime stage (minimal, no build tools)
FROM --platform=linux/amd64 python:3.10-slim

WORKDIR /app

# Create a non-root user first
RUN useradd -m -u 1000 converter

# Copy installed packages from builder stage to user directory
COPY --from=builder /root/.local /home/converter/.local

# Copy converter script
COPY convert_hf_to_mediapipe.py .

# Set ownership
RUN chown -R converter:converter /app && \
    chown -R converter:converter /home/converter/.local

USER converter

# Ensure local packages are in PATH
ENV PATH=/home/converter/.local/bin:$PATH \
    PYTHONPATH=/home/converter/.local/lib/python3.10/site-packages

# Default command
CMD ["python", "convert_hf_to_mediapipe.py", "--help"]

