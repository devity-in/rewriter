#!/usr/bin/env python3
"""
Convert Hugging Face Safetensors to MediaPipe Task format.

This script follows the official Google AI documentation for converting Gemma models
from Hugging Face Safetensors format (.safetensors) to MediaPipe Task format (.task).

Official documentation:
    https://ai.google.dev/gemma/docs/conversions/hf-to-mediapipe-task

The conversion process:
1. Loads the Gemma model using ai_edge_torch.generative (Gemma 2 or Gemma 3)
2. Converts to LiteRT (.tflite) with dynamic_int8 quantization
3. Packages into a .task file using mediapipe.tasks.python.genai.bundler

Requirements:
    pip install 'ai-edge-torch>=0.6.0' mediapipe

Usage:
    python convert_hf_to_mediapipe.py --input INPUT_PATH --output OUTPUT_PATH [OPTIONS]

Example (from official documentation):
    python convert_hf_to_mediapipe.py \\
        --input ../models/google/gemma-3-270m-it \\
        --output ../models/gemma_3_270m.task \\
        --architecture gemma3 \\
        --size 270m
"""

import argparse
import sys
from pathlib import Path
import tempfile
import shutil

try:
    from ai_edge_torch.generative.examples import gemma3, gemma2
    from ai_edge_torch.generative.utilities import converter
    from ai_edge_torch.generative.utilities.export_config import ExportConfig
    from ai_edge_torch.generative.layers import kv_cache
    from mediapipe.tasks.python.genai import bundler
except ImportError as e:
    error_msg = str(e)
    print("❌ Error: Required packages not installed or library loading failed.")
    print("")
    
    # Check if it's a library loading issue (common on macOS)
    if "libpywrap_litert_common.dylib" in error_msg or "Library not loaded" in error_msg:
        print("⚠️  This appears to be a library loading issue with ai-edge-torch on macOS.")
        print("")
        print("💡 Try these solutions:")
        print("")
        print("   1. Reinstall ai-edge-torch and dependencies:")
        print("      pip uninstall ai-edge-torch ai-edge-litert -y")
        print("      pip install --no-cache-dir 'ai-edge-torch>=0.6.0'")
        print("")
        print("   2. Or try installing tensorflow-lite-runtime separately:")
        print("      pip install tensorflow-lite-runtime")
        print("")
        print("   3. Check if you're using the correct Python version (3.10+):")
        print("      python --version")
        print("")
        print("   4. If the issue persists, this may be a known macOS compatibility issue.")
        print("      Consider using a different environment or checking the ai-edge-torch")
        print("      GitHub issues: https://github.com/google-ai-edge/ai-edge-torch/issues")
    else:
        print("   Please install: pip install 'ai-edge-torch>=0.6.0' mediapipe")
        print("   Or install from requirements.txt: pip install -r requirements.txt")
    
    print("")
    print(f"   Original error: {error_msg[:500]}...")
    sys.exit(1)
except Exception as e:
    error_msg = str(e)
    if "libpywrap_litert_common.dylib" in error_msg or "Library not loaded" in error_msg:
        print("❌ Error: Library loading issue with ai-edge-torch.")
        print("")
        print("💡 This is a known issue on macOS. Try:")
        print("   1. pip uninstall ai-edge-torch ai-edge-litert -y")
        print("   2. pip install --no-cache-dir 'ai-edge-torch>=0.6.0'")
        print("   3. Or check: https://github.com/google-ai-edge/ai-edge-torch/issues")
        print("")
        print(f"   Error: {error_msg[:300]}...")
        sys.exit(1)
    else:
        raise


def detect_model_architecture(input_path: Path) -> tuple[str, str]:
    """
    Detect model architecture and size from config.json.
    
    Returns:
        Tuple of (architecture, size) e.g., ('gemma3', '270m') or ('gemma2', '2b')
    """
    import json
    
    config_file = input_path / "config.json"
    if not config_file.exists():
        return None, None
    
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
        
        # Check model type and architecture
        model_type = config.get('model_type', '').lower()
        arch = config.get('architectures', [])
        
        # Detect Gemma models
        if 'gemma' in model_type or any('gemma' in str(a).lower() for a in arch):
            # Try to determine size from hidden_size or num_hidden_layers
            hidden_size = config.get('hidden_size', 0)
            num_layers = config.get('num_hidden_layers', 0)
            
            # Gemma 3 detection
            if 'gemma3' in model_type or any('gemma3' in str(a).lower() for a in arch):
                if hidden_size == 2048 or num_layers == 18:
                    return 'gemma3', '270m'
                elif hidden_size == 2560 or num_layers == 28:
                    return 'gemma3', '2b'
                elif hidden_size == 3072 or num_layers == 32:
                    return 'gemma3', '7b'
                else:
                    return 'gemma3', 'unknown'
            
            # Gemma 2 detection
            elif 'gemma2' in model_type or any('gemma2' in str(a).lower() for a in arch):
                if hidden_size == 2048 or num_layers == 18:
                    return 'gemma2', '270m'
                elif hidden_size == 2560 or num_layers == 28:
                    return 'gemma2', '2b'
                elif hidden_size == 3072 or num_layers == 32:
                    return 'gemma2', '7b'
                else:
                    return 'gemma2', 'unknown'
            
            # Generic Gemma
            else:
                if hidden_size == 2048 or num_layers == 18:
                    return 'gemma2', '270m'  # Default to gemma2 for older models
                elif hidden_size == 2560 or num_layers == 28:
                    return 'gemma2', '2b'
                else:
                    return 'gemma2', 'unknown'
        
        return None, None
        
    except Exception as e:
        print(f"   ⚠️  Could not parse config.json: {e}")
        return None, None


def validate_input_directory(input_path: Path) -> tuple[bool, str, str]:
    """
    Validate that the input directory contains required Hugging Face model files.
    
    Returns:
        Tuple of (is_valid, architecture, size)
    """
    required_files = {
        'config.json': False,
        'tokenizer.model': False,
    }
    
    # Check for safetensors files (at least one should exist)
    safetensors_files = list(input_path.glob("*.safetensors"))
    
    print(f"\n📁 Validating input directory: {input_path}")
    
    # Check config.json
    config_file = input_path / "config.json"
    if config_file.exists():
        required_files['config.json'] = True
        print(f"   ✅ Found config.json")
    else:
        print(f"   ❌ Missing config.json")
    
    # Check tokenizer.model
    tokenizer_file = input_path / "tokenizer.model"
    if tokenizer_file.exists():
        required_files['tokenizer.model'] = True
        print(f"   ✅ Found tokenizer.model")
    else:
        # Also check for tokenizer.json as alternative
        tokenizer_json = input_path / "tokenizer.json"
        if tokenizer_json.exists():
            print(f"   ⚠️  Found tokenizer.json (tokenizer.model preferred)")
        else:
            print(f"   ❌ Missing tokenizer.model")
    
    # Check safetensors
    if safetensors_files:
        print(f"   ✅ Found {len(safetensors_files)} safetensors file(s)")
        for sf in safetensors_files:
            size_mb = sf.stat().st_size / (1024 * 1024)
            print(f"      - {sf.name} ({size_mb:.2f} MB)")
    else:
        # Check for PyTorch .bin files as alternative
        bin_files = list(input_path.glob("*.bin"))
        if bin_files:
            print(f"   ⚠️  Found {len(bin_files)} .bin file(s) (safetensors preferred)")
        else:
            print(f"   ❌ Missing safetensors files")
    
    # At minimum, we need config.json and either safetensors or bin files
    has_config = required_files['config.json']
    has_weights = len(safetensors_files) > 0 or len(list(input_path.glob("*.bin"))) > 0
    
    if not has_config:
        print(f"\n❌ Error: Missing required config.json file")
        return False, None, None
    
    if not has_weights:
        print(f"\n❌ Error: Missing model weight files (.safetensors or .bin)")
        return False, None, None
    
    # Try to detect model architecture
    arch, size = detect_model_architecture(input_path)
    if arch:
        print(f"   🔍 Detected model: {arch} {size}")
    else:
        print(f"   ⚠️  Could not auto-detect model architecture")
    
    print(f"\n✅ Input directory validation passed")
    return True, arch, size


def load_model(input_hf_path: Path, architecture: str, size: str):
    """
    Load model using the appropriate builder function.
    
    Args:
        input_hf_path: Path to Hugging Face model directory
        architecture: Model architecture ('gemma2' or 'gemma3')
        size: Model size ('270m', '2b', '7b', etc.)
    
    Returns:
        PyTorch model object
    """
    model_path = str(input_hf_path)
    
    if architecture == 'gemma3':
        if size == '270m':
            return gemma3.build_model_270m(model_path)
        elif size == '1b':
            return gemma3.build_model_1b(model_path)
        elif size == '2b':
            return gemma3.build_model_2b(model_path)
        elif size == '7b':
            return gemma3.build_model_7b(model_path)
        else:
            # Try 270m as default
            print(f"   ⚠️  Unknown size '{size}', trying 270m...")
            return gemma3.build_model_270m(model_path)
    
    elif architecture == 'gemma2':
        if size == '270m':
            return gemma2.build_model_270m(model_path)
        elif size == '2b':
            return gemma2.build_model_2b(model_path)
        elif size == '7b':
            return gemma2.build_model_7b(model_path)
        else:
            # Try 270m as default
            print(f"   ⚠️  Unknown size '{size}', trying 270m...")
            return gemma2.build_model_270m(model_path)
    
    else:
        raise ValueError(f"Unsupported architecture: {architecture}. Supported: 'gemma2', 'gemma3'")


def convert_model(
    input_hf_path: Path,
    temp_tflite_path: Path,
    final_output_path: Path,
    architecture: str = None,
    size: str = None,
    tokenizer_path: Path = None,
    model_name_prefix: str = None,
    prefill_seq_len: int = 2048,
    kv_cache_max_len: int = 4096,
) -> bool:
    """
    Convert Hugging Face Safetensors to MediaPipe Task format.
    
    This function follows the official Google AI documentation:
    https://ai.google.dev/gemma/docs/conversions/hf-to-mediapipe-task
    
    The conversion process:
    1. Loads the Gemma model using ai_edge_torch.generative
    2. Converts to LiteRT (.tflite) with dynamic_int8 quantization
    3. Packages into a .task file using mediapipe bundler
    
    Args:
        input_hf_path: Path to directory containing Hugging Face model files
        temp_tflite_path: Temporary directory for the intermediate .tflite file
        final_output_path: Final output path for the .task file
        architecture: Model architecture ('gemma2' or 'gemma3'), auto-detected if None
        size: Model size ('270m', '1b', '2b', '7b'), auto-detected if None
        tokenizer_path: Optional path to tokenizer.model file (defaults to input_hf_path/tokenizer.model)
        model_name_prefix: Prefix for the tflite file name (defaults to architecture_size)
        prefill_seq_len: Prefill sequence length (default: 2048)
        kv_cache_max_len: KV cache max length (default: 4096)
    
    Returns:
        True if conversion successful, False otherwise
    """
    try:
        # Auto-detect architecture if not provided
        if architecture is None or size is None:
            print(f"\n🔍 Auto-detecting model architecture...")
            detected_arch, detected_size = detect_model_architecture(input_hf_path)
            if detected_arch and detected_size:
                architecture = architecture or detected_arch
                size = size or detected_size
                print(f"   ✅ Detected: {architecture} {size}")
            else:
                print(f"   ❌ Could not auto-detect architecture. Please specify --architecture and --size")
                return False
        
        if architecture not in ['gemma2', 'gemma3']:
            print(f"   ❌ Unsupported architecture: {architecture}. Supported: 'gemma2', 'gemma3'")
            return False
        
        print(f"\n🔄 Step 1: Loading {architecture} {size} model from {input_hf_path}")
        print(f"   This may take a few minutes for large models...")
        
        # Load the model using the appropriate builder
        pytorch_model = load_model(input_hf_path, architecture, size)
        
        print(f"   ✅ Model loaded successfully")
        
        print(f"\n🔄 Step 2: Converting to LiteRT (.tflite) with dynamic_int8 quantization")
        print(f"   Output directory: {temp_tflite_path}")
        print(f"   This may take several minutes...")
        
        # Create output directory if it doesn't exist
        temp_tflite_path.mkdir(parents=True, exist_ok=True)
        
        # Set model name prefix
        if model_name_prefix is None:
            model_name_prefix = f"{architecture}_{size}"
        
        # Configure export settings (following Google AI documentation)
        export_config = ExportConfig()
        export_config.kvcache_layout = kv_cache.KV_LAYOUT_TRANSPOSED
        export_config.mask_as_input = True
        
        # Convert to LiteRT with dynamic_int8 quantization
        # Reference: https://ai.google.dev/gemma/docs/conversions/hf-to-mediapipe-task
        converter.convert_to_tflite(
            pytorch_model,
            output_path=str(temp_tflite_path),
            output_name_prefix=model_name_prefix,
            prefill_seq_len=prefill_seq_len,
            kv_cache_max_len=kv_cache_max_len,
            quantize="dynamic_int8",
            export_config=export_config,
        )
        
        # Find the generated tflite file
        tflite_files = list(temp_tflite_path.glob(f"{model_name_prefix}*.tflite"))
        if not tflite_files:
            print(f"   ❌ Error: TFLite file was not created")
            return False
        
        tflite_file = tflite_files[0]
        size_mb = tflite_file.stat().st_size / (1024 * 1024)
        print(f"   ✅ TFLite conversion complete: {tflite_file.name} ({size_mb:.2f} MB)")
        
        print(f"\n🔄 Step 3: Packaging into MediaPipe GenAI .task file")
        print(f"   Output: {final_output_path}")
        
        # Determine tokenizer path
        if tokenizer_path is None:
            tokenizer_path = input_hf_path / "tokenizer.model"
        
        if not tokenizer_path.exists():
            # Try alternative tokenizer files
            tokenizer_json = input_hf_path / "tokenizer.json"
            if tokenizer_json.exists():
                print(f"   ⚠️  Using tokenizer.json instead of tokenizer.model")
                tokenizer_path = tokenizer_json
            else:
                print(f"   ❌ Error: Tokenizer file not found at {tokenizer_path}")
                return False
        
        # Use MediaPipe bundler to package the .tflite and tokenizer into .task file
        # Following Google AI documentation: https://ai.google.dev/gemma/docs/conversions/hf-to-mediapipe-task
        try:
            # Try using BundleConfig (recommended approach from documentation)
            config = bundler.BundleConfig(
                tflite_model=str(tflite_file),
                tokenizer_model=str(tokenizer_path),
                start_token="<bos>",
                stop_tokens=["<eos>", "<end_of_turn>"],
                output_filename=str(final_output_path),
                prompt_prefix="<start_of_turn>user\n",
                prompt_suffix="<end_of_turn>\n<start_of_turn>model\n",
            )
            bundler.create_bundle(config)
        except (AttributeError, TypeError) as e:
            # Fallback to simpler API if BundleConfig doesn't exist or has different signature
            print(f"   ⚠️  BundleConfig not available, trying fallback method: {e}")
            try:
                bundler.create_task(
                    model_path=str(tflite_file),
                    tokenizer_path=str(tokenizer_path),
                    output_path=str(final_output_path),
                )
            except AttributeError:
                # Final fallback
                bundler.create_task_bundle(
                    model_path=str(tflite_file),
                    tokenizer_path=str(tokenizer_path),
                    output_path=str(final_output_path),
                )
        
        # Check if task file was created
        if not final_output_path.exists():
            print(f"   ❌ Error: .task file was not created")
            return False
        
        size_mb = final_output_path.stat().st_size / (1024 * 1024)
        print(f"   ✅ Packaging complete ({size_mb:.2f} MB)")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error during conversion: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Convert Hugging Face model to MediaPipe GenAI .task format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples (following Google AI documentation):
  # Basic usage with auto-detection
  python convert_hf_to_mediapipe.py \\
      --input ../models/google/gemma-3-270m-it \\
      --output ../models/gemma_3_270m.task

  # With explicit architecture and size (Gemma 3 270M)
  python convert_hf_to_mediapipe.py \\
      --input ../models/google/gemma-3-270m-it \\
      --output ../models/gemma_3_270m.task \\
      --architecture gemma3 \\
      --size 270m

  # Gemma 3 1B model
  python convert_hf_to_mediapipe.py \\
      --input ../models/google/gemma-3-1b-it \\
      --output ../models/gemma_3_1b.task \\
      --architecture gemma3 \\
      --size 1b

  # With custom temporary directory and parameters
  python convert_hf_to_mediapipe.py \\
      --input ../models/google/gemma-3-2b-it \\
      --output ../models/gemma_3_2b.task \\
      --architecture gemma3 \\
      --size 2b \\
      --temp ./temp/tflite_output \\
      --prefill-seq-len 2048 \\
      --kv-cache-max-len 4096

Official documentation:
    https://ai.google.dev/gemma/docs/conversions/hf-to-mediapipe-task
        """
    )
    
    parser.add_argument(
        '--input',
        type=str,
        required=True,
        help='Path to directory containing Hugging Face model files (config.json, safetensors, tokenizer.model)'
    )
    
    parser.add_argument(
        '--output',
        type=str,
        required=True,
        help='Output path for the final .task file'
    )
    
    parser.add_argument(
        '--temp',
        type=str,
        default=None,
        help='Temporary directory for intermediate .tflite file (default: auto-generated in system temp)'
    )
    
    parser.add_argument(
        '--tokenizer',
        type=str,
        default=None,
        help='Path to tokenizer.model file (default: <input>/tokenizer.model)'
    )
    
    parser.add_argument(
        '--architecture',
        type=str,
        default=None,
        choices=['gemma2', 'gemma3'],
        help='Model architecture (auto-detected if not specified)'
    )
    
    parser.add_argument(
        '--size',
        type=str,
        default=None,
        choices=['270m', '1b', '2b', '7b'],
        help='Model size (auto-detected if not specified)'
    )
    
    parser.add_argument(
        '--prefill-seq-len',
        type=int,
        default=2048,
        help='Prefill sequence length (default: 2048)'
    )
    
    parser.add_argument(
        '--kv-cache-max-len',
        type=int,
        default=4096,
        help='KV cache max length (default: 4096)'
    )
    
    parser.add_argument(
        '--model-name-prefix',
        type=str,
        default=None,
        help='Prefix for the tflite file name (default: <architecture>_<size>)'
    )
    
    args = parser.parse_args()
    
    # Resolve and validate paths
    input_hf_path = Path(args.input).expanduser().resolve()
    final_output_path = Path(args.output).expanduser().resolve()
    
    # Validate input directory exists
    if not input_hf_path.exists():
        print(f"❌ Error: Input directory does not exist: {input_hf_path}")
        sys.exit(1)
    
    if not input_hf_path.is_dir():
        print(f"❌ Error: Input path is not a directory: {input_hf_path}")
        sys.exit(1)
    
    # Validate input directory contents
    is_valid, detected_arch, detected_size = validate_input_directory(input_hf_path)
    if not is_valid:
        sys.exit(1)
    
    # Use provided architecture/size or detected values
    architecture = args.architecture or detected_arch
    size = args.size or detected_size
    
    # Create output directory if it doesn't exist
    final_output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Determine temporary tflite path (should be a directory, not a file)
    if args.temp:
        temp_tflite_path = Path(args.temp).expanduser().resolve()
        temp_tflite_path.mkdir(parents=True, exist_ok=True)
    else:
        # Use system temp directory
        temp_dir = Path(tempfile.gettempdir())
        model_name = input_hf_path.name
        temp_tflite_path = temp_dir / f"{model_name}_temp_tflite"
        temp_tflite_path.mkdir(parents=True, exist_ok=True)
    
    # Determine tokenizer path
    tokenizer_path = None
    if args.tokenizer:
        tokenizer_path = Path(args.tokenizer).expanduser().resolve()
        if not tokenizer_path.exists():
            print(f"❌ Error: Tokenizer file does not exist: {tokenizer_path}")
            sys.exit(1)
    
    # Print configuration
    print("\n" + "=" * 60)
    print("🔧 Conversion Configuration")
    print("=" * 60)
    print(f"📥 Input HF Path:     {input_hf_path}")
    print(f"📦 Temp TFLite Dir:   {temp_tflite_path}")
    print(f"📤 Final Output Path: {final_output_path}")
    if architecture:
        print(f"🏗️  Architecture:       {architecture}")
    if size:
        print(f"📏 Model Size:          {size}")
    print(f"⚙️  Prefill Seq Len:    {args.prefill_seq_len}")
    print(f"⚙️  KV Cache Max Len:   {args.kv_cache_max_len}")
    if tokenizer_path:
        print(f"🔤 Tokenizer Path:     {tokenizer_path}")
    print("=" * 60)
    
    # Perform conversion
    success = convert_model(
        input_hf_path=input_hf_path,
        temp_tflite_path=temp_tflite_path,
        final_output_path=final_output_path,
        architecture=architecture,
        size=size,
        tokenizer_path=tokenizer_path,
        model_name_prefix=args.model_name_prefix,
        prefill_seq_len=args.prefill_seq_len,
        kv_cache_max_len=args.kv_cache_max_len,
    )
    
    if success:
        print("\n" + "=" * 60)
        print("✅ Conversion Complete!")
        print("=" * 60)
        print(f"📦 Output file: {final_output_path}")
        size_mb = final_output_path.stat().st_size / (1024 * 1024)
        print(f"📊 File size: {size_mb:.2f} MB")
        print(f"\n💡 Next steps:")
        print(f"   1. Use this model with the serve_models.py script")
        print(f"   2. Or place it in the models/ directory")
        print(f"   3. Configure in app: Settings → Local AI Model")
        print("=" * 60 + "\n")
        
        # Clean up temporary directory if it's in system temp
        if args.temp is None and temp_tflite_path.exists():
            try:
                shutil.rmtree(temp_tflite_path)
                print(f"🧹 Cleaned up temporary directory: {temp_tflite_path}")
            except Exception as e:
                print(f"⚠️  Could not clean up temporary directory: {e}")
    else:
        print("\n" + "=" * 60)
        print("❌ Conversion Failed")
        print("=" * 60)
        print(f"⚠️  Temporary files may remain at: {temp_tflite_path}")
        if not args.temp:
            print(f"💡 To keep temporary files, use --temp to specify a custom location")
        sys.exit(1)


if __name__ == "__main__":
    main()

