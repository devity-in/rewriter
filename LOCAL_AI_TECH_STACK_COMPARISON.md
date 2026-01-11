# Local AI Tech Stack Comparison

## Overview

This document compares different tech stacks for supporting multiple local AI models in your Flutter desktop app. Given your requirements (macOS, multiple model support, Flutter app), here are the best options.

## Recommendation: **Ollama + HTTP API** 🏆

### Why Ollama?
✅ **Supports 100+ models** (Llama, Mistral, Gemma, Phi, etc.)  
✅ **Easy to use** - Just install and run  
✅ **No native library issues** - Runs as separate process  
✅ **HTTP API** - Perfect for Flutter  
✅ **Automatic model management** - Downloads models automatically  
✅ **Cross-platform** - Works on macOS, Windows, Linux  
✅ **Active development** - Very popular, well-maintained  

### Architecture
```
Flutter App → HTTP Request → Ollama (localhost:11434) → Model Inference
```

### Implementation Steps

1. **Install Ollama**:
   ```bash
   brew install ollama  # macOS
   # or download from https://ollama.ai
   ```

2. **Start Ollama**:
   ```bash
   ollama serve
   ```

3. **Pull models** (first time, automatic):
   ```bash
   ollama pull llama2        # 7B model
   ollama pull mistral       # 7B model
   ollama pull gemma:2b      # 2B model (smaller)
   ollama pull phi            # 2.7B model (very fast)
   ollama pull qwen2.5:0.5b  # Tiny model for testing
   ```

4. **Flutter Integration**:
   - Create `lib/core/services/ollama_service.dart`
   - Call `http://localhost:11434/api/generate` with model name
   - No native dependencies needed!

### Pros
- ✅ Supports most popular models
- ✅ Easy to add new models (just `ollama pull`)
- ✅ No Flutter native asset issues
- ✅ Models managed automatically
- ✅ Good performance
- ✅ Well-documented API

### Cons
- ❌ Requires Ollama installed separately
- ❌ Models can be large (2-8 GB each)
- ❌ External dependency

---

## Alternative 1: **MLX (Apple Silicon Native)** 🍎

### Best For: macOS-only, Apple Silicon Macs

### Why MLX?
✅ **Native Apple Silicon** - Optimized for M1/M2/M3  
✅ **Fast** - Uses Metal GPU acceleration  
✅ **Lightweight** - Minimal dependencies  
✅ **Python-based** - Easy to integrate  
✅ **Supports many models** - Llama, Mistral, Phi, etc.  

### Architecture
```
Flutter App → HTTP Request → Python FastAPI Server → MLX → Model Inference
```

### Implementation Steps

1. **Install MLX**:
   ```bash
   pip install mlx mlx-lm
   ```

2. **Create Python server** (FastAPI):
   ```python
   from fastapi import FastAPI
   from mlx_lm import load, generate
   
   app = FastAPI()
   model, tokenizer = load("mlx-community/QwQ-32B-Preview-4bit")
   
   @app.post("/generate")
   async def generate_text(prompt: str):
       response = generate(model, tokenizer, prompt=prompt)
       return {"text": response}
   ```

3. **Flutter Integration**:
   - Call `http://localhost:8000/generate`
   - Similar to Ollama approach

### Pros
- ✅ Best performance on Apple Silicon
- ✅ Native Metal GPU support
- ✅ Good model support
- ✅ Python ecosystem

### Cons
- ❌ macOS/Apple Silicon only
- ❌ Requires Python server
- ❌ More setup complexity

---

## Alternative 2: **Local HTTP Server (Python + transformers)** 🐍

### Best For: Maximum flexibility

### Why This?
✅ **Full control** - Use any model from Hugging Face  
✅ **Flexible** - Can customize inference  
✅ **No vendor lock-in**  
✅ **Many options** - PyTorch, TensorFlow, ONNX  

### Architecture
```
Flutter App → HTTP Request → Python FastAPI → transformers/onnxruntime → Model
```

### Implementation Steps

1. **Install dependencies**:
   ```bash
   pip install fastapi uvicorn transformers torch onnxruntime
   ```

2. **Create server**:
   ```python
   from fastapi import FastAPI
   from transformers import pipeline
   
   app = FastAPI()
   generator = pipeline("text-generation", model="microsoft/phi-2")
   
   @app.post("/generate")
   async def generate(prompt: str):
       result = generator(prompt, max_length=100)
       return {"text": result[0]["generated_text"]}
   ```

3. **Flutter Integration**:
   - Standard HTTP client
   - Same as Ollama

### Pros
- ✅ Maximum flexibility
- ✅ Any Hugging Face model
- ✅ Full control over inference

### Cons
- ❌ More complex setup
- ❌ Higher memory usage
- ❌ Slower than optimized solutions

---

## Alternative 3: **llama.cpp + HTTP Wrapper** ⚡

### Best For: Maximum performance

### Why llama.cpp?
✅ **Very fast** - Optimized C++ implementation  
✅ **Low memory** - Efficient quantization  
✅ **Many models** - Supports GGUF format  
✅ **Cross-platform**  

### Architecture
```
Flutter App → HTTP Request → llama.cpp server → Model (.gguf)
```

### Implementation Steps

1. **Install llama.cpp**:
   ```bash
   git clone https://github.com/ggerganov/llama.cpp
   cd llama.cpp && make
   ```

2. **Use server mode**:
   ```bash
   ./server -m model.gguf --port 8080
   ```

3. **Flutter Integration**:
   - Call REST API
   - Similar to Ollama

### Pros
- ✅ Very fast inference
- ✅ Low memory usage
- ✅ Efficient quantization support

### Cons
- ❌ Requires building from source
- ❌ More manual model management
- ❌ Less user-friendly than Ollama

---

## Alternative 4: **MediaPipe GenAI (Current)** 📦

### Current Status
- ❌ Limited to Gemma models only
- ❌ Native asset build issues
- ❌ Complex setup

### Keep It If:
- You only need Gemma models
- Native assets issue gets fixed
- You want fully embedded solution

---

## Comparison Table

| Feature | Ollama | MLX | Python Server | llama.cpp | MediaPipe |
|---------|--------|-----|---------------|-----------|-----------|
| **Model Support** | ⭐⭐⭐⭐⭐ 100+ | ⭐⭐⭐⭐ 50+ | ⭐⭐⭐⭐⭐ Any | ⭐⭐⭐⭐ Many | ⭐⭐ Gemma only |
| **Ease of Setup** | ⭐⭐⭐⭐⭐ Very Easy | ⭐⭐⭐ Moderate | ⭐⭐ Complex | ⭐⭐⭐ Moderate | ⭐ Very Complex |
| **Performance** | ⭐⭐⭐⭐ Good | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐ Good | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐ Good |
| **Cross-Platform** | ⭐⭐⭐⭐⭐ Yes | ⭐ macOS only | ⭐⭐⭐⭐⭐ Yes | ⭐⭐⭐⭐⭐ Yes | ⭐⭐⭐ Limited |
| **Flutter Integration** | ⭐⭐⭐⭐⭐ HTTP API | ⭐⭐⭐⭐ HTTP API | ⭐⭐⭐⭐⭐ HTTP API | ⭐⭐⭐⭐ HTTP API | ⭐ Native (issues) |
| **Model Management** | ⭐⭐⭐⭐⭐ Auto | ⭐⭐⭐ Manual | ⭐⭐ Manual | ⭐⭐ Manual | ⭐⭐ Manual |
| **Memory Usage** | ⭐⭐⭐ Moderate | ⭐⭐⭐⭐ Low | ⭐⭐ High | ⭐⭐⭐⭐⭐ Very Low | ⭐⭐⭐⭐ Low |
| **Active Development** | ⭐⭐⭐⭐⭐ Very Active | ⭐⭐⭐⭐ Active | ⭐⭐⭐⭐ Active | ⭐⭐⭐⭐⭐ Very Active | ⭐⭐⭐ Limited |

---

## Recommended Implementation Plan

### Phase 1: Add Ollama Support (Recommended First Step)

1. **Create OllamaService**:
   ```dart
   class OllamaService implements AIService {
     final String baseUrl = 'http://localhost:11434';
     final String modelName;
     
     Future<RewriteResult> rewriteText(String text, {String style}) async {
       // POST to /api/generate
       // Model: llama2, mistral, gemma:2b, phi, etc.
     }
   }
   ```

2. **Add to settings UI**:
   - Model selector dropdown
   - Ollama status indicator
   - Auto-detect if Ollama is running

3. **Add service check**:
   - Verify Ollama is running on startup
   - Show helpful error if not installed

### Phase 2: Keep Gemini as Fallback
- Use Gemini API when Ollama unavailable
- Or use Gemini when internet available (better quality)

### Phase 3: Optional - Add MLX for macOS
- For users with Apple Silicon
- Better performance option

---

## Code Example: Ollama Service

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class OllamaService implements AIService {
  static const String baseUrl = 'http://localhost:11434';
  final String modelName;
  
  OllamaService({this.modelName = 'mistral'}); // or 'llama2', 'gemma:2b', etc.
  
  @override
  Future<RewriteResult> rewriteText(
    String text, {
    String style = 'professional',
  }) async {
    try {
      final prompt = 'Rewrite the following text in a $style style: $text';
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': modelName,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.7,
            'max_tokens': 512,
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rewritten = data['response'] as String;
        return RewriteResult.success(
          originalText: text,
          rewrittenText: rewritten.trim(),
        );
      } else {
        return RewriteResult.failure(
          originalText: text,
          error: 'Ollama error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return RewriteResult.failure(
        originalText: text,
        error: 'Failed to connect to Ollama: $e',
      );
    }
  }
  
  @override
  Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/tags'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
```

---

## Quick Start: Ollama Integration

1. **Install Ollama**: `brew install ollama` or download from ollama.ai
2. **Start Ollama**: `ollama serve` (or it auto-starts)
3. **Pull a model**: `ollama pull mistral` (or `phi` for smaller/faster)
4. **Add OllamaService** to your codebase
5. **Update settings** to select Ollama as model type
6. **Done!** 🎉

---

## Model Recommendations for Text Rewriting

### Fast & Small (Good for Testing)
- `phi` (2.7B) - Very fast, good quality
- `gemma:2b` (2B) - Fast, decent quality
- `qwen2.5:0.5b` (0.5B) - Tiny, very fast

### Balanced (Recommended)
- `mistral` (7B) - Great quality, reasonable speed
- `llama2` (7B) - Good quality, well-tested
- `gemma:7b` (7B) - Good quality

### Best Quality (Slower)
- `llama3:8b` (8B) - Excellent quality
- `mistral-nemo` (12B) - Very high quality

---

## Conclusion

**For your use case (Flutter desktop app, multiple models, macOS):**

🏆 **Use Ollama** - It's the easiest, most flexible, and best-supported solution.

**Benefits:**
- No native asset issues
- Supports 100+ models
- Easy Flutter integration (HTTP API)
- Active community
- Works cross-platform

**Next Steps:**
1. Install Ollama
2. Implement OllamaService
3. Add model selection UI
4. Keep Gemini as optional fallback

This gives you the flexibility to support many models while avoiding the native asset complexity of MediaPipe GenAI.

