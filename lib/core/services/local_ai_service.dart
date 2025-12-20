import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_genai/mediapipe_genai.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/rewrite_result.dart';
import 'ai_service.dart';

/// Service for interacting with local AI models using Mediapipe GenAI
class LocalAIService implements AIService {
  LlmInferenceEngine? _llmEngine;
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Initialize the local AI model
  Future<void> initialize({String? customModelPath}) async {
    if (_isInitialized || _isInitializing) {
      return;
    }

    _isInitializing = true;
    try {
      debugPrint('LocalAIService: Initializing Mediapipe GenAI...');

      // Try to find model file
      String? modelPath;

      // First, try custom path if provided
      if (customModelPath != null) {
        final customFile = File(customModelPath);
        if (await customFile.exists()) {
          modelPath = customModelPath;
          debugPrint('LocalAIService: Found model at custom path: $modelPath');
        }
      }

      // Try common download locations
      if (modelPath == null) {
        final downloadsDir = Directory(
          '${Platform.environment['HOME']}/Downloads',
        );
        if (await downloadsDir.exists()) {
          // Try specific model name first
          final specificPath = '${downloadsDir.path}/functiongemma_270m.task';
          final specificFile = File(specificPath);
          if (await specificFile.exists()) {
            modelPath = specificPath;
            debugPrint('LocalAIService: Found model at: $modelPath');
          } else {
            // Try to find any .task file in Downloads
            try {
              final taskFiles = downloadsDir
                  .listSync()
                  .where(
                    (entity) => entity is File && entity.path.endsWith('.task'),
                  )
                  .cast<File>()
                  .toList();
              if (taskFiles.isNotEmpty) {
                modelPath = taskFiles.first.path;
                debugPrint('LocalAIService: Found model at: $modelPath');
              }
            } catch (e) {
              debugPrint('LocalAIService: Error searching Downloads: $e');
            }
          }
        }
      }

      // Try to load model from assets
      if (modelPath == null) {
        try {
          // Try FunctionGemma model first (successfully converted)
          final gemmaAssetPath = 'assets/models/functiongemma_270m.task';
          final bundle = rootBundle;
          final assetData = await bundle.load(gemmaAssetPath);

          // Copy asset to filesystem (Mediapipe needs a file path)
          final cacheDir = await getApplicationDocumentsDirectory();
          final modelsDir = Directory('${cacheDir.path}/models');
          if (!await modelsDir.exists()) {
            await modelsDir.create(recursive: true);
          }
          final gemmaFile = File('${modelsDir.path}/functiongemma_270m.task');
          await gemmaFile.writeAsBytes(assetData.buffer.asUint8List());
          modelPath = gemmaFile.path;
          debugPrint(
            'LocalAIService: Found FunctionGemma model in assets, copied to: $modelPath',
          );
        } catch (e) {
          debugPrint(
            'LocalAIService: FunctionGemma model not found in assets: $e',
          );
        }
      }

      // If still not found, fail silently - model will be unavailable
      if (modelPath == null) {
        debugPrint('LocalAIService: No model file found, local AI unavailable');
        throw Exception('Local AI model not available');
      }

      // Validate model file exists and has reasonable size
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception('Model file does not exist: $modelPath');
      }

      final fileSize = await modelFile.length();
      if (fileSize < 1024) {
        // Model files should be at least 1KB
        throw Exception(
          'Model file appears to be invalid (too small: $fileSize bytes)',
        );
      }
      debugPrint(
        'LocalAIService: Model file validated: $modelPath (${fileSize ~/ 1024}KB)',
      );

      // Initialize LlmInferenceEngine
      // Try GPU first, fallback to CPU
      // Note: The actual FFI session creation happens when generateResponse is called,
      // so we'll handle FFI errors there with proper error handling
      try {
        final options = LlmInferenceOptions.gpu(
          modelPath: modelPath,
          maxTokens: 512,
          temperature: 0.7,
          topK: 40,
          sequenceBatchSize: 1,
        );
        _llmEngine = LlmInferenceEngine(options);
        debugPrint(
          'LocalAIService: Created GPU engine (session will be created on first use)',
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        // Check if this is a native library issue during engine creation
        if (errorStr.contains('symbol not found') ||
            errorStr.contains('native function') ||
            errorStr.contains('no available native assets') ||
            errorStr.contains('couldn\'t resolve native') ||
            errorStr.contains('dlsym')) {
          debugPrint(
            'LocalAIService: Native libraries not available - Mediapipe GenAI may not support macOS desktop',
          );
          _llmEngine = null;
          throw Exception(
            'Local AI native libraries not available on macOS desktop. '
            'Mediapipe GenAI package may not have macOS support yet. '
            'Please use Gemini API instead.',
          );
        }

        debugPrint(
          'LocalAIService: GPU engine creation failed, trying CPU: $e',
        );
        // Get cache directory for CPU (required)
        final cacheDir = await getApplicationDocumentsDirectory();
        final modelCacheDir = Directory('${cacheDir.path}/local_ai_models');
        if (!await modelCacheDir.exists()) {
          await modelCacheDir.create(recursive: true);
        }
        try {
          final options = LlmInferenceOptions.cpu(
            modelPath: modelPath,
            cacheDir: modelCacheDir.path,
            maxTokens: 512,
            temperature: 0.7,
            topK: 40,
          );
          _llmEngine = LlmInferenceEngine(options);
          debugPrint(
            'LocalAIService: Created CPU engine (session will be created on first use)',
          );
        } catch (cpuError) {
          final cpuErrorStr = cpuError.toString().toLowerCase();
          // Check if CPU also has native library issues
          if (cpuErrorStr.contains('symbol not found') ||
              cpuErrorStr.contains('native function') ||
              cpuErrorStr.contains('no available native assets') ||
              cpuErrorStr.contains('couldn\'t resolve native') ||
              cpuErrorStr.contains('dlsym')) {
            debugPrint(
              'LocalAIService: Native libraries not available for CPU either',
            );
            _llmEngine = null;
            throw Exception(
              'Local AI native libraries not available on macOS desktop. '
              'Mediapipe GenAI package may not have macOS support yet. '
              'Please use Gemini API instead.',
            );
          }
          debugPrint(
            'LocalAIService: CPU engine creation also failed: $cpuError',
          );
          _llmEngine = null;
          throw Exception(
            'Both GPU and CPU engine creation failed. Last error: $cpuError',
          );
        }
      }

      _isInitialized = true;
      debugPrint('LocalAIService: Initialized successfully');
    } catch (e) {
      debugPrint('LocalAIService: Initialization error: $e');
      _isInitialized = false;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Rewrite text using local AI model
  @override
  Future<RewriteResult> rewriteText(
    String text, {
    String style = 'professional',
  }) async {
    try {
      // Ensure initialized
      if (!_isInitialized) {
        await initialize();
      }

      if (_llmEngine == null) {
        return RewriteResult.failure(
          originalText: text,
          error: 'Local AI model not initialized',
        );
      }

      final prompt = _buildPrompt(text, style);
      debugPrint(
        'LocalAIService: Generating response for: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
      );

      // Generate response using Mediapipe GenAI (returns a stream)
      // Wrap in try-catch to handle FFI errors gracefully
      Stream<String> responseStream;
      try {
        responseStream = _llmEngine!.generateResponse(prompt);
      } catch (e) {
        debugPrint('LocalAIService: Failed to create response stream: $e');
        final errorStr = e.toString().toLowerCase();
        // Check if this is a native library missing error
        if (errorStr.contains('symbol not found') ||
            errorStr.contains('native function') ||
            errorStr.contains('no available native assets') ||
            errorStr.contains('couldn\'t resolve native') ||
            errorStr.contains('ffi') ||
            errorStr.contains('dlsym')) {
          // Reset initialization state - native libraries aren't available
          _isInitialized = false;
          _llmEngine = null;
          return RewriteResult.failure(
            originalText: text,
            error:
                'Local AI native libraries not available on this platform. '
                'Mediapipe GenAI may not support macOS desktop yet. '
                'Please use Gemini API instead.',
          );
        }
        rethrow;
      }

      // Collect all chunks from the stream
      final responseBuffer = StringBuffer();
      try {
        await for (final chunk in responseStream) {
          responseBuffer.write(chunk);
        }
      } catch (e) {
        debugPrint('LocalAIService: Error reading response stream: $e');
        final errorStr = e.toString().toLowerCase();
        // Check if this is a native library missing error
        if (errorStr.contains('symbol not found') ||
            errorStr.contains('native function') ||
            errorStr.contains('no available native assets') ||
            errorStr.contains('couldn\'t resolve native') ||
            errorStr.contains('ffi') ||
            errorStr.contains('dlsym')) {
          // Reset initialization state - native libraries aren't available
          _isInitialized = false;
          _llmEngine = null;
          return RewriteResult.failure(
            originalText: text,
            error:
                'Local AI native libraries not available on this platform. '
                'Mediapipe GenAI may not support macOS desktop yet. '
                'Please use Gemini API instead.',
          );
        }
        rethrow;
      }

      final response = responseBuffer.toString();

      if (response.isEmpty) {
        return RewriteResult.failure(
          originalText: text,
          error: 'Empty response from local AI model',
        );
      }

      // Extract rewritten text from response
      final rewrittenText = _extractRewrittenText(response, text);

      if (rewrittenText == null || rewrittenText.isEmpty) {
        return RewriteResult.failure(
          originalText: text,
          error: 'Could not extract rewritten text from response',
        );
      }

      return RewriteResult.success(
        originalText: text,
        rewrittenText: rewrittenText,
      );
    } catch (e) {
      debugPrint('LocalAIService: Error rewriting text: $e');
      return RewriteResult.failure(originalText: text, error: e.toString());
    }
  }

  /// Build prompt for rewriting
  String _buildPrompt(String text, String style) {
    final styleInstructions = {
      'professional':
          'Rewrite this sentence in a professional and clear manner:',
      'casual': 'Rewrite this sentence in a casual and friendly manner:',
      'concise': 'Rewrite this sentence more concisely:',
      'academic': 'Rewrite this sentence in an academic style:',
    };

    final instruction =
        styleInstructions[style] ?? styleInstructions['professional']!;

    return '$instruction\n\n"$text"\n\nProvide only the rewritten sentence without quotes or additional explanation.';
  }

  /// Extract rewritten text from model response
  String? _extractRewrittenText(String response, String originalText) {
    // Try to extract just the rewritten sentence
    // The model might return the full prompt + response, so we need to extract just the rewritten part

    // Remove the prompt part if present
    String cleaned = response.trim();

    // Remove quotes if present
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }

    // If response contains the original text, try to extract what comes after
    final originalIndex = cleaned.toLowerCase().indexOf(
      originalText.toLowerCase(),
    );
    if (originalIndex != -1) {
      // Try to find the rewritten part after the original
      final afterOriginal = cleaned
          .substring(originalIndex + originalText.length)
          .trim();
      if (afterOriginal.isNotEmpty &&
          afterOriginal.length > originalText.length * 0.5) {
        cleaned = afterOriginal;
      }
    }

    // Remove any remaining prompt text
    final promptMarkers = [
      'Rewrite this sentence',
      'Provide only',
      'without quotes',
    ];
    for (final marker in promptMarkers) {
      final index = cleaned.toLowerCase().indexOf(marker.toLowerCase());
      if (index != -1) {
        cleaned = cleaned.substring(0, index).trim();
      }
    }

    return cleaned.isNotEmpty ? cleaned : response.trim();
  }

  /// Test connection to local AI model
  @override
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (_llmEngine == null) {
        return false;
      }

      final result = await rewriteText('Test', style: 'professional');
      return result.success;
    } catch (e) {
      debugPrint('LocalAIService: Test connection failed: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    // Mediapipe GenAI engine cleanup
    _llmEngine = null;
    _isInitialized = false;
  }
}
