import 'package:mediapipe_genai/mediapipe_genai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
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

  /// Callback for removal progress: (removed bytes, total bytes, modelName)
  Function(int, int, String)? onRemoveProgress;

  /// Callback for initialization status changes
  Function(String)?
  onStatusChanged; // 'downloading', 'initializing', 'ready', 'error'

  // Throttle progress updates to avoid blocking UI
  Timer? _progressThrottleTimer;
  DateTime? _lastProgressUpdate;
  static const Duration _progressThrottleInterval = Duration(milliseconds: 100);

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
    // Call status callback directly - UI handles async updates
    onStatusChanged?.call('downloading');

    try {
      // Download model from URL at runtime (required by MediaPipe GenAI)
      _modelPath = await _downloadModel(modelUrl);

      // Validate model file exists
      final modelFile = File(_modelPath!);
      if (!await modelFile.exists()) {
        throw Exception('Model file does not exist: $_modelPath');
      }

      // Call status callback directly - UI handles async updates
      onStatusChanged?.call('initializing');

      // Initialize LlmInferenceEngine following MediaPipe GenAI documentation
      // Following the example pattern: try GPU first, fallback to CPU if needed
      try {
        // Try GPU mode first (as per official example)
        final gpuOptions = LlmInferenceOptions.gpu(
          modelPath: _modelPath!,
          maxTokens: 512,
          temperature: 0.7,
          topK: 40,
          sequenceBatchSize: 1,
        );
        _llmEngine = LlmInferenceEngine(gpuOptions);
      } catch (e) {
        // Check if this is a native library loading error first
        final errorString = e.toString();
        if (errorString.contains('native function') ||
            errorString.contains('symbol not found') ||
            errorString.contains('native assets') ||
            errorString.contains('No available native assets')) {
          throw Exception(
            '❌ Native libraries not found for MediaPipe GenAI.\n\n'
            'The native libraries need to be downloaded during the build process.\n'
            'This usually means:\n'
            '1. Native assets were not downloaded/built correctly\n'
            '2. The build.dart script failed to download libraries from Google Cloud Storage\n'
            '3. Network issues prevented downloading native libraries\n\n'
            'Try these steps:\n'
            '1. Run: ./scripts/setup_local_ai.sh\n'
            '2. Or manually rebuild: flutter clean && flutter pub get && flutter build macos --debug\n'
            '3. Check build logs: find build -name "*build-log*.txt"\n'
            '4. Verify native assets: cat .dart_tool/flutter_build/*/native_assets.json\n'
            '5. Check network connectivity (libraries download from storage.googleapis.com)\n\n'
            'The package DOES support macOS - native libraries just need to be downloaded.\n'
            'If the issue persists, check:\n'
            '- https://pub.dev/packages/mediapipe_genai\n'
            '- GitHub issues: https://github.com/google/flutter-mediapipe/issues\n\n'
            'Original error: $errorString',
          );
        }

        // If GPU fails but not due to native libraries, try CPU mode with cacheDir (as shown in example)
        if (errorString.contains('GPU') || errorString.contains('gpu')) {
          try {
            final cacheDir = await getApplicationCacheDirectory();
            final cpuOptions = LlmInferenceOptions.cpu(
              modelPath: _modelPath!,
              cacheDir: cacheDir.path,
              maxTokens: 512,
              temperature: 0.7,
              topK: 40,
            );
            _llmEngine = LlmInferenceEngine(cpuOptions);
          } catch (cpuError) {
            // Check if CPU also failed due to native libraries
            final cpuErrorString = cpuError.toString();
            if (cpuErrorString.contains('native function') ||
                cpuErrorString.contains('symbol not found') ||
                cpuErrorString.contains('native assets')) {
              throw Exception(
                '❌ Native libraries not found for MediaPipe GenAI.\n\n'
                'The native libraries need to be downloaded during the build process.\n'
                'Both GPU and CPU initialization failed due to missing native libraries.\n\n'
                'Try these steps:\n'
                '1. Run: ./scripts/setup_local_ai.sh\n'
                '2. Or manually rebuild: flutter clean && flutter pub get && flutter build macos --debug\n'
                '3. Check build logs: find build -name "*build-log*.txt"\n\n'
                'Original errors: GPU: $errorString, CPU: $cpuErrorString',
              );
            }
            // Re-throw the CPU error with context
            throw Exception(
              'Failed to initialize MediaPipe GenAI with both GPU and CPU modes. '
              'GPU error: $e. CPU error: $cpuError',
            );
          }
        } else {
          // Re-throw non-GPU, non-native-library errors
          rethrow;
        }
      }

      _isInitialized = true;
      _isInitializing = false;
      // Call status callback directly - UI handles async updates
      onStatusChanged?.call('ready');
    } catch (e) {
      _isInitialized = false;
      _isInitializing = false;
      // Call status callback directly - UI handles async updates
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
      // Report 100% if cached - use immediate report
      if (onDownloadProgress != null) {
        onDownloadProgress!(fileSize, fileSize);
      }
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

          // Report initial progress (0%) to show download has started
          if (contentLength > 0) {
            _reportProgressImmediate(0, contentLength);
          } else {
            _reportProgressImmediate(0, 0);
          }

          // Open file for writing (streaming to avoid memory issues)
          final sink = cachedFile.openWrite();

          try {
            // Download with progress tracking - stream directly to file
            await for (final chunk in streamedResponse.stream) {
              // Write chunk directly to file (non-blocking)
              sink.add(chunk);
              downloadedBytes += chunk.length;

              // Throttle progress updates to avoid blocking UI
              _throttledProgressUpdate(downloadedBytes, contentLength);
            }

            // Ensure all data is written
            await sink.flush();
          } finally {
            await sink.close();
          }

          // Report final completion
          _reportProgressImmediate(downloadedBytes, contentLength);

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

  /// Get the models directory path
  Future<Directory> _getModelsDirectory() async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${cacheDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// List all downloaded models
  /// Returns a list of model info: {name, path, size}
  Future<List<Map<String, dynamic>>> listDownloadedModels() async {
    final modelsDir = await _getModelsDirectory();
    final files = modelsDir.listSync();
    final models = <Map<String, dynamic>>[];

    for (final file in files) {
      if (file is File && file.path.endsWith('.task')) {
        final stat = await file.stat();
        models.add({
          'name': file.path.split('/').last,
          'path': file.path,
          'size': stat.size,
          'modified': stat.modified,
        });
      }
    }

    // Sort by modified date (newest first)
    models.sort(
      (a, b) =>
          (b['modified'] as DateTime).compareTo(a['modified'] as DateTime),
    );

    return models;
  }

  /// Remove a downloaded model
  /// [modelPath] - Full path to the model file to remove
  /// Returns true if successful, false otherwise
  Future<bool> removeModel(String modelPath) async {
    try {
      final file = File(modelPath);
      if (!await file.exists()) {
        return false;
      }

      final fileSize = await file.length();
      final fileName = file.path.split('/').last;

      // Report initial progress
      onRemoveProgress?.call(0, fileSize, fileName);

      // Small delay to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 100));

      // Delete the file
      await file.delete();

      // Report completion
      onRemoveProgress?.call(fileSize, fileSize, fileName);

      // If this was the currently loaded model, reset the service
      if (_modelPath == modelPath) {
        _llmEngine = null;
        _isInitialized = false;
        _modelPath = null;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove a model by name
  /// [modelName] - Name of the model file (e.g., 'model.task')
  Future<bool> removeModelByName(String modelName) async {
    final modelsDir = await _getModelsDirectory();
    final modelPath = '${modelsDir.path}/$modelName';
    return await removeModel(modelPath);
  }

  /// Get total size of all downloaded models
  Future<int> getTotalModelsSize() async {
    final models = await listDownloadedModels();
    int totalSize = 0;
    for (final model in models) {
      totalSize += model['size'] as int;
    }
    return totalSize;
  }

  /// Throttle progress updates to avoid blocking UI thread
  void _throttledProgressUpdate(int downloadedBytes, int totalBytes) {
    final now = DateTime.now();

    // If this is the first update or enough time has passed, update immediately
    if (_lastProgressUpdate == null ||
        now.difference(_lastProgressUpdate!) >= _progressThrottleInterval) {
      _reportProgressImmediate(downloadedBytes, totalBytes);
      _lastProgressUpdate = now;
      return;
    }

    // Otherwise, cancel existing timer and schedule update
    _progressThrottleTimer?.cancel();
    _progressThrottleTimer = Timer(_progressThrottleInterval, () {
      _reportProgressImmediate(downloadedBytes, totalBytes);
      _lastProgressUpdate = DateTime.now();
    });
  }

  /// Report progress immediately (used for final update)
  void _reportProgressImmediate(int downloadedBytes, int totalBytes) {
    // Cancel any pending throttled updates
    _progressThrottleTimer?.cancel();
    _progressThrottleTimer = null;
    _lastProgressUpdate = DateTime.now();

    // Call progress callback directly - UI handles setState asynchronously
    if (onDownloadProgress != null) {
      if (totalBytes > 0) {
        onDownloadProgress!(downloadedBytes, totalBytes);
      } else {
        onDownloadProgress!(downloadedBytes, downloadedBytes);
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _progressThrottleTimer?.cancel();
    _progressThrottleTimer = null;
    _lastProgressUpdate = null;
    _llmEngine = null;
    _isInitialized = false;
  }
}
