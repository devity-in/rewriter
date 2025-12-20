FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory (will be overridden by docker run -w)
WORKDIR /workspace/converter

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy converter script
COPY convert_phi3.py .

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Default command (will be overridden by docker run command)
CMD ["python", "convert_phi3.py"]
