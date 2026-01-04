#!/usr/bin/env python3
"""
Simple HTTP server to serve MediaPipe GenAI model files locally.
This allows the app to download models at runtime as required by MediaPipe GenAI.

Usage:
    python3 scripts/serve_models.py [--port PORT] [--directory DIR]

Default:
    Port: 8000
    Directory: ./models
"""

import argparse
import http.server
import socketserver
import os
import sys
from pathlib import Path

# Default configuration
DEFAULT_PORT = 8000
DEFAULT_DIRECTORY = "models"


class ModelFileHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler that serves files with proper headers for model downloads."""
    
    def end_headers(self):
        # Add CORS headers to allow localhost requests
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        # Add cache control headers
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()
    
    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS preflight."""
        self.send_response(200)
        self.end_headers()
    
    def log_message(self, format, *args):
        """Custom logging to show what files are being served."""
        message = format % args
        # Only log GET requests, not HEAD requests (which browsers send)
        if 'GET' in message:
            print(f"[{self.log_date_time_string()}] {message}")


def main():
    parser = argparse.ArgumentParser(
        description='Serve MediaPipe GenAI model files locally',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Serve from default directory (./models) on port 8000
  python3 scripts/serve_models.py

  # Serve on custom port
  python3 scripts/serve_models.py --port 8080

  # Serve from custom directory
  python3 scripts/serve_models.py --directory ~/my_models

  # Custom port and directory
  python3 scripts/serve_models.py --port 8080 --directory ./models
        """
    )
    
    parser.add_argument(
        '--port',
        type=int,
        default=DEFAULT_PORT,
        help=f'Port to serve on (default: {DEFAULT_PORT})'
    )
    
    parser.add_argument(
        '--directory',
        type=str,
        default=DEFAULT_DIRECTORY,
        help=f'Directory to serve files from (default: {DEFAULT_DIRECTORY})'
    )
    
    args = parser.parse_args()
    
    # Resolve directory path
    models_dir = Path(args.directory).expanduser().resolve()
    
    # Check if directory exists
    if not models_dir.exists():
        print(f"Error: Directory does not exist: {models_dir}")
        print(f"\nCreating directory: {models_dir}")
        try:
            models_dir.mkdir(parents=True, exist_ok=True)
            print(f"✅ Directory created successfully")
        except Exception as e:
            print(f"❌ Failed to create directory: {e}")
            sys.exit(1)
    
    if not models_dir.is_dir():
        print(f"Error: Path is not a directory: {models_dir}")
        sys.exit(1)
    
    # Check for model files
    model_files = list(models_dir.glob("*.task"))
    if not model_files:
        print(f"⚠️  Warning: No .task files found in {models_dir}")
        print(f"   Place your MediaPipe GenAI model files (.task) in this directory")
    else:
        print(f"✅ Found {len(model_files)} model file(s):")
        for model_file in model_files:
            size_mb = model_file.stat().st_size / (1024 * 1024)
            print(f"   - {model_file.name} ({size_mb:.2f} MB)")
    
    # Change to models directory
    os.chdir(models_dir)
    
    # Create server
    handler = ModelFileHandler
    httpd = socketserver.TCPServer(("", args.port), handler)
    
    # Get local IP addresses
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    print("\n" + "=" * 60)
    print("🚀 Model Server Started")
    print("=" * 60)
    print(f"📁 Serving directory: {models_dir}")
    print(f"🌐 Server URLs:")
    print(f"   - http://localhost:{args.port}")
    print(f"   - http://127.0.0.1:{args.port}")
    print(f"   - http://{local_ip}:{args.port}")
    print(f"\n📝 To use in the app:")
    print(f"   1. Open Settings → Local AI Model")
    print(f"   2. Enter model URL: http://localhost:{args.port}/your_model.task")
    print(f"   3. Or use: http://localhost:{args.port}/")
    print(f"\n⚠️  Keep this server running while using the app")
    print(f"   Press Ctrl+C to stop the server")
    print("=" * 60 + "\n")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\n🛑 Server stopped")
        httpd.shutdown()
        sys.exit(0)


if __name__ == "__main__":
    main()

