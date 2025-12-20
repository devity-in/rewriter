#!/usr/bin/env python3
"""
Convert Mediapipe-compatible models from SafeTensors to Mediapipe Task format
Direct conversion without Docker - uses Mediapipe source code

Supports: Gemma models (GEMMA3_300M, GEMMA3_1B, GEMMA3_4B, etc.)
"""
import os
import sys
from pathlib import Path

# Add Mediapipe source to path
MEDIAPIPE_PATH = "/Users/bw/abhishekthakur/mediapipe"
mediapipe_python_path = os.path.join(MEDIAPIPE_PATH, "mediapipe", "tasks", "python")
if os.path.exists(mediapipe_python_path):
    sys.path.insert(0, mediapipe_python_path)
    print(f"Using Mediapipe source from: {mediapipe_python_path}")
else:
    print(f"ERROR: Mediapipe source not found at: {mediapipe_python_path}")
    print("Please ensure Mediapipe source code is available")
    sys.exit(1)

# Paths - can be overridden via environment variables
PROJECT_ROOT = Path(__file__).parent.parent
HF_MODEL_PATH = os.environ.get(
    "MODEL_PATH",
    "/Users/bw/.cache/huggingface/hub/models--google--functiongemma-270m-it/snapshots/ead2a1f9df8d6431408ccff6c9e5e60028addde0",
)
MODEL_TYPE = os.environ.get("MODEL_TYPE", "GEMMA3_300M")
OUTPUT_DIR = PROJECT_ROOT / "converter" / "output"
TASK_OUTPUT = PROJECT_ROOT / "assets" / "models" / "model.task"

# Clean output directory for fresh start
if OUTPUT_DIR.exists():
    import shutil
    print("Cleaning output directory...")
    shutil.rmtree(OUTPUT_DIR)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
(PROJECT_ROOT / "assets" / "models").mkdir(parents=True, exist_ok=True)

def convert_with_mediapipe():
    """Convert SafeTensors to Mediapipe Task format using Mediapipe converter"""
    print("=" * 60)
    print("Converting Model using Mediapipe Converter")
    print("=" * 60)
    print(f"Input: {HF_MODEL_PATH}")
    print(f"Model Type: {MODEL_TYPE}")
    print(f"Output: {TASK_OUTPUT}")
    
    if not os.path.exists(HF_MODEL_PATH):
        print(f"ERROR: Model directory not found: {HF_MODEL_PATH}")
        return False
    
    # Check for tokenizer file
    tokenizer_path = Path(HF_MODEL_PATH) / "tokenizer.model"
    vocab_model_file = str(tokenizer_path) if tokenizer_path.exists() else None
    
    if not vocab_model_file:
        # Try HuggingFace format (tokenizer.json + tokenizer_config.json)
        tokenizer_json = Path(HF_MODEL_PATH) / "tokenizer.json"
        tokenizer_config = Path(HF_MODEL_PATH) / "tokenizer_config.json"
        if tokenizer_json.exists() and tokenizer_config.exists():
            vocab_model_file = str(HF_MODEL_PATH)  # Directory with tokenizer files
            print(f"Using HuggingFace tokenizer files from: {vocab_model_file}")
        else:
            print("WARNING: tokenizer files not found")
            model_files = list(Path(HF_MODEL_PATH).iterdir())
            print(f"Files in model directory: {[f.name for f in model_files]}")
    
    try:
        from mediapipe.tasks.python.genai.converter import llm_converter
        
        print("\nCreating conversion config...")
        
        # Build config
        config_params = {
            'input_ckpt': str(HF_MODEL_PATH),
            'ckpt_format': 'safetensors',
            'model_type': MODEL_TYPE,
            'backend': 'cpu',
            'output_dir': str(OUTPUT_DIR),
            'combine_file_only': False,
            'vocab_model_file': vocab_model_file or '',
            'output_tflite_file': str(TASK_OUTPUT),
        }
        
        # Add optional quantization parameters if they exist
        import inspect
        sig = inspect.signature(llm_converter.ConversionConfig.__init__)
        param_names = list(sig.parameters.keys())[1:]  # Skip 'self'
        
        if 'is_symmetric' in param_names:
            config_params['is_symmetric'] = True
        if 'attention_quant_bits' in param_names:
            config_params['attention_quant_bits'] = 8
        if 'feedforward_quant_bits' in param_names:
            config_params['feedforward_quant_bits'] = 8
        if 'embedding_quant_bits' in param_names:
            config_params['embedding_quant_bits'] = 8
        
        print(f"Creating config with parameters: {list(config_params.keys())}")
        print(f"Model type: {config_params['model_type']}")
        config = llm_converter.ConversionConfig(**config_params)
        
        print("\nStarting conversion...")
        print("This may take 10-20 minutes...")
        print(f"Output directory: {OUTPUT_DIR}")
        
        # Convert checkpoint
        llm_converter.convert_checkpoint(config)
        
        if TASK_OUTPUT.exists():
            print(f"\n✓ Conversion complete!")
            print(f"  File: {TASK_OUTPUT}")
            file_size = TASK_OUTPUT.stat().st_size / (1024 * 1024)  # MB
            print(f"  Size: {file_size:.2f} MB")
            return True
        else:
            print("\n✗ Task file not found after conversion")
            output_files = list(OUTPUT_DIR.glob("*"))
            if output_files:
                print(f"Found files in output directory: {[f.name for f in output_files[:10]]}")
            return False
            
    except ImportError as e:
        print(f"\n✗ Error importing Mediapipe converter: {e}")
        print("\nPlease ensure Mediapipe source code is available at:")
        print(f"  {MEDIAPIPE_PATH}")
        return False
    except Exception as e:
        print(f"\n✗ Error during conversion: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("Mediapipe Model Converter (Direct - No Docker)")
    print("=" * 60)
    print(f"Project Root: {PROJECT_ROOT}")
    print(f"Model Source: {HF_MODEL_PATH}")
    print(f"Model Type: {MODEL_TYPE}")
    print(f"Final Output: {TASK_OUTPUT}")
    print("=" * 60)
    print("\nUsage:")
    print("  MODEL_PATH=/path/to/model MODEL_TYPE=GEMMA3_300M python convert_model.py")
    print("")
    
    if not convert_with_mediapipe():
        print("\n✗ Conversion failed")
        print("\nTroubleshooting:")
        print("1. Ensure Mediapipe source code is available")
        print("2. Check that all dependencies are installed: pip install sentencepiece jax jaxlib")
        print("3. Verify the model directory contains model.safetensors and tokenizer files")
        print("4. Check MODEL_TYPE matches your model (GEMMA3_300M, GEMMA3_1B, etc.)")
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("✓ Conversion Complete!")
    print("=" * 60)
    print(f"\nModel file ready at: {TASK_OUTPUT}")
    print("\nNext steps:")
    print("1. Rename the output file if needed:")
    print(f"   mv {TASK_OUTPUT} assets/models/your_model_name.task")
    print("2. Update pubspec.yaml to include the asset:")
    print("   assets:")
    print("     - assets/models/your_model_name.task")
    print("3. Update your Flutter code to use this model")
    print("4. Run: flutter pub get")
    print("5. Restart your app")

if __name__ == "__main__":
    main()
