import 'package:mediapipe_genai/mediapipe_genai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../models/rewrite_result.dart';
import 'ai_service.dart';

/// Service for interacting with local AI models using MediaPipe GenAI
/// Follows official MediaPipe GenAI guidelines: https://ai.google.dev/gemma/docs/conversions/hf-to-mediapipe-task
class LocalAIService implements AIService {
  LlmInferenceEngine? _llmEngine;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _modelPath;

  /// Callback for download progress: (downloaded bytes, total bytes)
  Function(int, int)? onDownloadProgress;

  /// Callback for initialization status changes
  Function(String)?
  onStatusChanged; // 'downloading', 'initializing', 'ready', 'error'

  /// Initialize the local AI model
  ///
  /// Following MediaPipe GenAI official documentation: models must be downloaded at runtime.
  /// The model will be downloaded from [modelUrl] and cached locally for future use.
  ///
  /// [modelUrl] - URL to download the model file (.task format) from
  Future<void> initialize({required String modelUrl}) async {
    if (_isInitialized) {
      return;
    }

    if (_isInitializing) {
      // Already initializing, wait for it to complete
      return;
    }

    if (modelUrl.isEmpty) {
      throw Exception(
        'Model URL is required. '
        'MediaPipe GenAI requires models to be downloaded at runtime. '
        'Please configure a model URL in settings.',
      );
    }

    _isInitializing = true;
    onStatusChanged?.call('downloading');

    try {
      // Download model from URL at runtime (required by MediaPipe GenAI)
      _modelPath = await _downloadModel(modelUrl);

      // Validate model file exists
      final modelFile = File(_modelPath!);
      if (!await modelFile.exists()) {
        throw Exception('Model file does not exist: $_modelPath');
      }

      onStatusChanged?.call('initializing');

      // Initialize LlmInferenceEngine following MediaPipe GenAI documentation
      // Use GPU options as per official examples
      // Note: GPU will automatically fallback to CPU if GPU is not available
      final options = LlmInferenceOptions.gpu(
        modelPath: _modelPath!,
        maxTokens: 512,
        temperature: 0.7,
        topK: 40,
        sequenceBatchSize: 1,
      );
      _llmEngine = LlmInferenceEngine(options);

      _isInitialized = true;
      _isInitializing = false;
      onStatusChanged?.call('ready');
    } catch (e) {
      _isInitialized = false;
      _isInitializing = false;
      onStatusChanged?.call('error');
      rethrow;
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if service is currently initializing
  bool get isInitializing => _isInitializing;

  /// Rewrite text using local AI model
  /// Following MediaPipe GenAI official usage pattern
  @override
  Future<RewriteResult> rewriteText(
    String text, {
    String style = 'professional',
  }) async {
    if (!_isInitialized || _llmEngine == null) {
      return RewriteResult.failure(
        originalText: text,
        error: 'Local AI model not initialized',
      );
    }

    try {
      // Build simple prompt following MediaPipe GenAI best practices
      final prompt = _buildPrompt(text, style);

      // Generate response using MediaPipe GenAI
      final responseStream = _llmEngine!.generateResponse(prompt);

      // Collect response chunks
      final responseBuffer = StringBuffer();
      await for (final chunk in responseStream) {
        responseBuffer.write(chunk);
      }

      final response = responseBuffer.toString().trim();

      if (response.isEmpty) {
        return RewriteResult.failure(
          originalText: text,
          error: 'Empty response from model',
        );
      }

      return RewriteResult.success(originalText: text, rewrittenText: response);
    } catch (e) {
      return RewriteResult.failure(originalText: text, error: e.toString());
    }
  }

  /// Build prompt for rewriting
  String _buildPrompt(String text, String style) {
    final instruction = 'Rewrite the following text in a $style style: $text';
    return instruction;
  }

  /// Test connection to local AI model
  ///
  /// Note: This requires the service to already be initialized with a model.
  /// The test will fail if no model has been configured.
  @override
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized || _llmEngine == null) {
        // Cannot test if not initialized - need model URL first
        return false;
      }
      final result = await rewriteText('Test', style: 'professional');
      return result.success;
    } catch (e) {
      return false;
    }
  }

  /// Download model from URL at runtime
  /// Following MediaPipe GenAI documentation: models must be downloaded at runtime
  /// Includes retry logic and progress reporting
  Future<String> _downloadModel(String url, {int maxRetries = 3}) async {
    // Create cache directory
    final cacheDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${cacheDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    // Generate filename from URL
    final uri = Uri.parse(url);
    final fileName = uri.path.split('/').last;
    final cachedModelPath = '${modelsDir.path}/$fileName';

    // Check if model already exists in cache
    final cachedFile = File(cachedModelPath);
    if (await cachedFile.exists()) {
      final fileSize = await cachedFile.length();
      onDownloadProgress?.call(fileSize, fileSize); // Report 100% if cached
      return cachedModelPath;
    }

    // Download model with retry logic
    Exception? lastException;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Create HTTP client with longer timeout for large files
        final client = http.Client();

        try {
          final request = http.Request('GET', uri);
          final streamedResponse = await client
              .send(request)
              .timeout(
                const Duration(
                  minutes: 30,
                ), // Longer timeout for large model files
                onTimeout: () {
                  throw Exception(
                    'Download timeout after 30 minutes. '
                    'This may happen with very large model files or slow connections.',
                  );
                },
              );

          if (streamedResponse.statusCode != 200) {
            throw Exception(
              'Failed to download model: HTTP ${streamedResponse.statusCode}',
            );
          }

          // Get content length for progress tracking
          final contentLength = streamedResponse.contentLength ?? 0;
          int downloadedBytes = 0;

          // Download with progress tracking
          final fileBytes = <int>[];
          await for (final chunk in streamedResponse.stream) {
            fileBytes.addAll(chunk);
            downloadedBytes += chunk.length;

            // Report progress if callback is set
            if (contentLength > 0) {
              onDownloadProgress?.call(downloadedBytes, contentLength);
            } else {
              // If content length unknown, report downloaded bytes
              onDownloadProgress?.call(downloadedBytes, downloadedBytes);
            }
          }

          // Save model file
          await cachedFile.writeAsBytes(fileBytes);

          // Report completion
          if (contentLength > 0) {
            onDownloadProgress?.call(contentLength, contentLength);
          } else {
            onDownloadProgress?.call(fileBytes.length, fileBytes.length);
          }

          return cachedModelPath;
        } finally {
          client.close();
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt < maxRetries) {
          // Wait before retry with exponential backoff
          final delaySeconds = attempt * 2;
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
      }
    }

    // All retries failed
    throw lastException ??
        Exception('Failed to download model after $maxRetries attempts');
  }

  /// Dispose resources
  void dispose() {
    _llmEngine = null;
    _isInitialized = false;
  }
}
