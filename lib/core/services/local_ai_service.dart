import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_genai/mediapipe_genai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../models/rewrite_result.dart';
import 'ai_service.dart';

/// Service for interacting with local AI models using Mediapipe GenAI
class LocalAIService implements AIService {
  LlmInferenceEngine? _llmEngine;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _modelUrl;
  bool _isGenerating = false; // Track if a generation is in progress

  // Track download progress streams
  final _downloadControllers = <String, StreamController<int>>{};

  /// Initialize the local AI model
  Future<void> initialize({
    String? customModelPath,
    String? modelUrl,
    String? kaggleUsername,
    String? kaggleKey,
  }) async {
    if (_isInitialized || _isInitializing) {
      return;
    }

    _isInitializing = true;
    try {
      debugPrint('LocalAIService: Initializing Mediapipe GenAI...');

      // Note: MediaPipe GenAI supports macOS desktop according to official documentation
      // Native-assets experiment must be enabled: `flutter config --enable-native-assets`
      // Then run `flutter pub get` and rebuild the app
      if (Platform.isMacOS) {
        debugPrint(
          'LocalAIService: macOS detected - MediaPipe GenAI supports macOS',
        );
        debugPrint(
          'LocalAIService: Ensure native-assets is enabled: `flutter config --enable-native-assets`',
        );
      }

      // Store model URL if provided
      _modelUrl = modelUrl;

      // Get model path - supports custom path, Downloads folder, assets, or runtime download
      final modelPath = await getModelPath(
        customModelPath,
        modelUrl,
        kaggleUsername: kaggleUsername,
        kaggleKey: kaggleKey,
      );

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

        // Skip session creation test during initialization
        // The test creates a session that can interfere with actual requests
        // MediaPipe GenAI doesn't allow concurrent sessions, so testing here
        // can cause "previous controller is still active" errors
        // We'll catch errors when actually using the engine instead
        debugPrint(
          'LocalAIService: Skipping session test - will catch errors on first actual use',
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        // Check if this is a native assets configuration issue
        if (errorStr.contains('symbol not found') ||
            errorStr.contains('native function') ||
            errorStr.contains('no available native assets') ||
            errorStr.contains('couldn\'t resolve native') ||
            errorStr.contains('dlsym')) {
          debugPrint(
            'LocalAIService: Native assets not available - configuration issue',
          );
          _llmEngine = null;
          throw Exception(
            'Local AI native assets not available.\n\n'
            'To fix this:\n'
            '1. Enable native-assets: `flutter config --enable-native-assets`\n'
            '2. Run: `flutter pub get`\n'
            '3. Clean and rebuild: `flutter clean && flutter run`\n\n'
            'Alternatively, switch to Gemini API in settings.',
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
          // Check if CPU also has native assets configuration issues
          if (cpuErrorStr.contains('symbol not found') ||
              cpuErrorStr.contains('native function') ||
              cpuErrorStr.contains('no available native assets') ||
              cpuErrorStr.contains('couldn\'t resolve native') ||
              cpuErrorStr.contains('dlsym')) {
            debugPrint(
              'LocalAIService: Native assets not available for CPU either',
            );
            _llmEngine = null;
            throw Exception(
              'Local AI native assets not available.\n\n'
              'To fix this:\n'
              '1. Enable native-assets: `flutter config --enable-native-assets`\n'
              '2. Run: `flutter pub get`\n'
              '3. Clean and rebuild: `flutter clean && flutter run`\n\n'
              'Alternatively, switch to Gemini API in settings.',
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

      // Check if a generation is already in progress
      // MediaPipe GenAI doesn't allow concurrent generateResponse calls
      if (_isGenerating) {
        debugPrint(
          'LocalAIService: Generation already in progress, rejecting concurrent request',
        );
        return RewriteResult.failure(
          originalText: text,
          error:
              'Another rewrite is already in progress. Please wait for it to complete.',
        );
      }

      _isGenerating = true;

      try {
        final prompt = _buildPrompt(text, style);
        debugPrint(
          'LocalAIService: Generating response for: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
        );

        // Generate response using Mediapipe GenAI (returns a stream)
        // Wrap in try-catch to handle FFI errors gracefully
        // Note: Errors from isolates may occur when the stream is consumed, not when created
        Stream<String> responseStream;
        try {
          responseStream = _llmEngine!.generateResponse(prompt);
        } catch (e) {
          debugPrint('LocalAIService: Failed to create response stream: $e');
          final errorStr = e.toString().toLowerCase();

          // Check for concurrent call error
          if (errorStr.contains('should not call') ||
              errorStr.contains('previous controller is still active') ||
              errorStr.contains('_responsecontroller')) {
            return RewriteResult.failure(
              originalText: text,
              error:
                  'Another rewrite is already in progress. Please wait for it to complete.',
            );
          }

          // Check if this is a native assets configuration error
          if (errorStr.contains('symbol not found') ||
              errorStr.contains('native function') ||
              errorStr.contains('no available native assets') ||
              errorStr.contains('couldn\'t resolve native') ||
              errorStr.contains('ffi') ||
              errorStr.contains('dlsym') ||
              errorStr.contains('unhandled exception') ||
              errorStr.contains('invalid argument')) {
            // Reset initialization state - native assets aren't configured correctly
            _isInitialized = false;
            _llmEngine = null;
            return RewriteResult.failure(
              originalText: text,
              error:
                  'Local AI native assets not available. '
                  'Ensure native-assets experiment is enabled: `flutter config --enable-native-assets`. '
                  'Then run `flutter pub get` and rebuild the app. '
                  'Alternatively, use Gemini API instead.',
            );
          }
          rethrow;
        }

        // Collect all chunks from the stream
        // Set up zone error handler to catch isolate errors
        final responseBuffer = StringBuffer();
        final completer = Completer<void>();
        final errorCompleter = Completer<Object>();

        // Set up error handler for unhandled errors in isolates
        // The error occurs when the isolate tries to create the session
        runZonedGuarded(
          () async {
            try {
              await for (final chunk in responseStream) {
                responseBuffer.write(chunk);
              }
              if (!completer.isCompleted) {
                completer.complete();
              }
            } catch (e, stack) {
              debugPrint('LocalAIService: Error reading response stream: $e');
              debugPrint('Stack trace: $stack');
              if (!errorCompleter.isCompleted) {
                errorCompleter.complete(e);
              }
            }
          },
          (error, stack) {
            debugPrint(
              'LocalAIService: Unhandled error in zone when reading stream: $error',
            );
            debugPrint('Stack trace: $stack');
            // Check if this is the native assets error or concurrent call error
            final errorStr = error.toString().toLowerCase();
            if (errorStr.contains('couldn\'t resolve native function') ||
                errorStr.contains('no available native assets') ||
                errorStr.contains('symbol not found') ||
                errorStr.contains('llminferenceengine_createsession')) {
              debugPrint(
                'LocalAIService: Detected native assets error in isolate',
              );
            }
            if (errorStr.contains('should not call') ||
                errorStr.contains('previous controller is still active') ||
                errorStr.contains('_responsecontroller') ||
                errorStr.contains('failed assertion')) {
              debugPrint(
                'LocalAIService: Detected concurrent call error in isolate',
              );
            }
            if (!errorCompleter.isCompleted) {
              errorCompleter.complete(error);
            }
          },
        );

        // Wait for either completion or error
        try {
          await Future.any([
            completer.future,
            errorCompleter.future.then((e) => throw e),
          ]).timeout(Duration(seconds: 30));

          // Ensure stream is fully consumed and MediaPipe's internal controller is released
          // MediaPipe needs time to clean up its internal state after stream completion
          // Increase delay to ensure controller is fully released
          await Future.delayed(Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('LocalAIService: Error reading response stream: $e');
          final errorStr = e.toString().toLowerCase();

          // Check for concurrent call error first
          if (errorStr.contains('should not call') ||
              errorStr.contains('previous controller is still active') ||
              errorStr.contains('_responsecontroller') ||
              errorStr.contains('failed assertion')) {
            return RewriteResult.failure(
              originalText: text,
              error:
                  'Another rewrite is already in progress. Please wait for it to complete.',
            );
          }

          // Check if this is a native assets configuration error
          // The error message includes: "Couldn't resolve native function 'LlmInferenceEngine_CreateSession'"
          // and "No available native assets" and "No asset with id"
          if (errorStr.contains('symbol not found') ||
              errorStr.contains('native function') ||
              errorStr.contains('no available native assets') ||
              errorStr.contains('no asset with id') ||
              errorStr.contains('couldn\'t resolve native') ||
              errorStr.contains('llminferenceengine_createsession') ||
              errorStr.contains('mediapipe_genai_bindings') ||
              errorStr.contains('ffi') ||
              errorStr.contains('dlsym') ||
              errorStr.contains('unhandled exception') ||
              errorStr.contains('invalid argument')) {
            // Reset initialization state - native assets aren't configured correctly
            _isInitialized = false;
            _llmEngine = null;
            return RewriteResult.failure(
              originalText: text,
              error:
                  'Local AI native assets not available. '
                  'Ensure native-assets experiment is enabled: `flutter config --enable-native-assets`. '
                  'Then run `flutter pub get` and rebuild the app. '
                  'Alternatively, use Gemini API instead.',
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
      } finally {
        // Always clear the generating flag when done
        _isGenerating = false;
      }
    } catch (e) {
      debugPrint('LocalAIService: Error rewriting text: $e');
      _isGenerating = false; // Ensure flag is cleared on error

      final errorStr = e.toString().toLowerCase();
      // Check for concurrent call error in catch block too
      if (errorStr.contains('should not call') ||
          errorStr.contains('previous controller is still active') ||
          errorStr.contains('_responsecontroller') ||
          errorStr.contains('failed assertion')) {
        return RewriteResult.failure(
          originalText: text,
          error:
              'Another rewrite is already in progress. Please wait for it to complete.',
        );
      }

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

      // Check if generation is in progress
      if (_isGenerating) {
        debugPrint(
          'LocalAIService: Cannot test connection - generation in progress',
        );
        return false;
      }

      final result = await rewriteText('Test', style: 'professional');
      return result.success;
    } catch (e) {
      debugPrint('LocalAIService: Test connection failed: $e');
      return false;
    }
  }

  /// Get model path - supports multiple sources:
  /// 1. Custom path (if provided)
  /// 2. Downloads folder (manually placed)
  /// 3. Assets (bundled with app, copied to filesystem)
  /// 4. Runtime download from URL (including Kaggle API)
  ///
  /// Location where you downloaded the file at runtime, or
  /// placed the model yourself in advance (using `adb push`
  /// or similar)
  ///
  /// According to MediaPipe GenAI docs, models must be downloaded at runtime
  /// from a URL hosted by the developer. Models can be obtained from Kaggle
  /// and self-hosted.
  Future<String> getModelPath(
    String? customModelPath,
    String? modelUrl, {
    String? kaggleUsername,
    String? kaggleKey,
  }) async {
    // First, try custom path if provided
    if (customModelPath != null) {
      final customFile = File(customModelPath);
      if (await customFile.exists()) {
        debugPrint(
          'LocalAIService: Found model at custom path: $customModelPath',
        );
        return customModelPath;
      }
    }

    // Try common download locations (manually placed)
    final downloadsDir = Directory('${Platform.environment['HOME']}/Downloads');
    if (await downloadsDir.exists()) {
      // Try specific model name first
      final specificPath = '${downloadsDir.path}/functiongemma_270m.task';
      final specificFile = File(specificPath);
      if (await specificFile.exists()) {
        debugPrint('LocalAIService: Found model in Downloads: $specificPath');
        return specificPath;
      }

      // Try to find any .task file in Downloads
      try {
        final taskFiles = downloadsDir
            .listSync()
            .where((entity) => entity is File && entity.path.endsWith('.task'))
            .cast<File>()
            .toList();
        if (taskFiles.isNotEmpty) {
          debugPrint(
            'LocalAIService: Found model in Downloads: ${taskFiles.first.path}',
          );
          return taskFiles.first.path;
        }
      } catch (e) {
        debugPrint('LocalAIService: Error searching Downloads: $e');
      }
    }

    // Try to load model from assets (bundled with app)
    // MediaPipe needs a file path, so we copy from assets to filesystem
    try {
      final gemmaAssetPath = 'assets/models/functiongemma_270m.task';
      final bundle = rootBundle;
      final assetData = await bundle.load(gemmaAssetPath);

      // Copy asset to filesystem
      final cacheDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${cacheDir.path}/models');
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }
      final gemmaFile = File('${modelsDir.path}/functiongemma_270m.task');

      // Only copy if file doesn't exist or is different size
      if (!await gemmaFile.exists() ||
          await gemmaFile.length() != assetData.lengthInBytes) {
        await gemmaFile.writeAsBytes(assetData.buffer.asUint8List());
      }

      debugPrint(
        'LocalAIService: Found model in assets, copied to: ${gemmaFile.path}',
      );
      return gemmaFile.path;
    } catch (e) {
      debugPrint('LocalAIService: Model not found in assets: $e');
    }

    // Try runtime download from URL (as per MediaPipe GenAI documentation)
    // Models must be downloaded at runtime from a URL hosted by the developer
    final urlToUse = modelUrl ?? _modelUrl;
    if (urlToUse != null && urlToUse.isNotEmpty) {
      try {
        // Check if it's a Kaggle URL
        if (urlToUse.contains('kaggle.com')) {
          if (kaggleUsername != null && kaggleKey != null) {
            return await _downloadModelFromKaggle(
              urlToUse,
              kaggleUsername,
              kaggleKey,
            );
          } else {
            throw Exception(
              'Kaggle credentials required for Kaggle downloads. '
              'Please provide kaggleUsername and kaggleKey.',
            );
          }
        } else {
          return await _downloadModelFromUrl(urlToUse);
        }
      } catch (e) {
        debugPrint('LocalAIService: Failed to download model from URL: $e');
        // Continue to throw exception below
      }
    }

    // If still not found, throw exception
    throw Exception(
      'Local AI model not available.\n\n'
      'Options:\n'
      '1. Place a .task model file in Downloads folder\n'
      '2. Bundle the model in assets/models/\n'
      '3. Configure a model URL in settings to download at runtime\n\n'
      'To get models: Create a Kaggle account, download models, '
      'and self-host them at a URL of your choosing.',
    );
  }

  /// Download model from URL at runtime with progress tracking
  /// Models are cached locally to avoid re-downloading
  /// Returns the file path and an optional progress stream
  Future<(Future<String>, Stream<int>?)> downloadModelFromUrl(
    String url, {
    Function(int percent)? onProgress,
  }) async {
    debugPrint('LocalAIService: Downloading model from URL: $url');

    // Create cache directory for downloaded models
    final cacheDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${cacheDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    // Generate filename from URL (use last segment or hash of URL)
    final uri = Uri.parse(url);
    final urlPath = uri.path;
    final fileName = urlPath.isNotEmpty && urlPath.endsWith('.task')
        ? urlPath.split('/').last
        : 'model_${url.hashCode}.task';

    final cachedModelPath = '${modelsDir.path}/$fileName';

    // Check if model already exists in cache
    final cachedFile = File(cachedModelPath);
    if (await cachedFile.exists()) {
      final fileSize = await cachedFile.length();
      if (fileSize > 1024) {
        // Model exists and has reasonable size, use cached version
        debugPrint(
          'LocalAIService: Using cached model from: $cachedModelPath (${fileSize ~/ 1024}KB)',
        );
        return (Future.value(cachedModelPath), null);
      } else {
        // File exists but is too small, delete and re-download
        await cachedFile.delete();
        debugPrint('LocalAIService: Cached model too small, re-downloading');
      }
    }

    // Check if download is already in progress
    if (_downloadControllers.containsKey(url)) {
      debugPrint('LocalAIService: Download already in progress for: $url');
      return (
        _waitForDownloadCompletion(cachedModelPath),
        _downloadControllers[url]!.stream,
      );
    }

    // Start new download
    final progressStream = await _downloadModelWithProgress(
      url,
      cachedModelPath,
      onProgress: onProgress,
    );

    return (Future.value(cachedModelPath), progressStream);
  }

  /// Internal method to download model with progress tracking
  Future<Stream<int>> _downloadModelWithProgress(
    String url,
    String downloadDestination, {
    Function(int percent)? onProgress,
  }) async {
    // Setup progress stream controller (broadcast for multiple listeners)
    final progressController = StreamController<int>.broadcast();
    _downloadControllers[url] = progressController;

    // Start download in background and return stream immediately
    _performDownload(
          url,
          downloadDestination,
          progressController,
          onProgress: onProgress,
        )
        .then((_) {
          // Download completed successfully
          progressController.add(100);
          onProgress?.call(100);
          progressController.close();
          _downloadControllers.remove(url);
        })
        .catchError((error) async {
          debugPrint('LocalAIService: Download error: $error');
          // Clean up partial download (ignore errors during cleanup)
          try {
            await File(downloadDestination).delete();
          } catch (_) {
            // Ignore cleanup errors
          }
          progressController.addError(error);
          progressController.close();
          _downloadControllers.remove(url);
        });

    return progressController.stream;
  }

  /// Perform the actual download operation
  Future<void> _performDownload(
    String url,
    String downloadDestination,
    StreamController<int> progressController, {
    Function(int percent)? onProgress,
  }) async {
    debugPrint('LocalAIService: Starting download to: $downloadDestination');

    // Setup the request
    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send().timeout(
      Duration(minutes: 10),
      onTimeout: () {
        throw Exception('Model download timed out after 10 minutes');
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download model: HTTP ${response.statusCode}');
    }

    // Get content length for progress calculation
    final contentLengthHeader = response.headers['content-length'];
    final contentLength = contentLengthHeader != null
        ? int.tryParse(contentLengthHeader) ?? 0
        : 0;

    debugPrint(
      'LocalAIService: Downloading ${contentLength > 0 ? "${contentLength ~/ 1024}KB" : "unknown size"}',
    );

    // Create file sink for writing
    final fileSink = File(downloadDestination).openWrite();
    int downloadedBytes = 0;
    int lastPercentEmitted = -1;

    // Download with progress tracking
    await response.stream.forEach((List<int> bytes) {
      fileSink.add(bytes);
      downloadedBytes += bytes.length;

      if (contentLength > 0) {
        final percent = ((downloadedBytes / contentLength) * 100).toInt();
        // Emit progress every 1% to avoid too many updates
        if (percent > lastPercentEmitted) {
          progressController.add(percent);
          onProgress?.call(percent);
          lastPercentEmitted = percent;
          debugPrint('LocalAIService: Download progress: $percent%');
        }
      }
    });

    await fileSink.close();

    // Verify file was downloaded successfully
    final downloadedFile = File(downloadDestination);
    if (!await downloadedFile.exists()) {
      throw Exception('Downloaded file does not exist');
    }

    final fileSize = await downloadedFile.length();
    if (fileSize < 1024) {
      throw Exception('Downloaded model file is too small: $fileSize bytes');
    }

    debugPrint(
      'LocalAIService: Model downloaded successfully: $downloadDestination (${fileSize ~/ 1024}KB)',
    );
  }

  /// Wait for download completion by checking file existence
  Future<String> _waitForDownloadCompletion(String filePath) async {
    final file = File(filePath);
    while (!await file.exists()) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    return filePath;
  }

  /// Download model from Kaggle API
  /// Handles authentication and tar.gz extraction
  Future<String> _downloadModelFromKaggle(
    String kaggleUrl,
    String username,
    String apiKey,
  ) async {
    debugPrint('LocalAIService: Downloading model from Kaggle: $kaggleUrl');

    // Create cache directory for downloaded models
    final cacheDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${cacheDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    // Generate filename from URL
    final uri = Uri.parse(kaggleUrl);
    final modelName = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'kaggle_model_${kaggleUrl.hashCode}';
    final archivePath = '${modelsDir.path}/$modelName.tar.gz';
    final extractedDir = Directory('${modelsDir.path}/${modelName}_extracted');

    // Check if model already exists (extracted)
    final taskFiles = await _findTaskFilesInDirectory(modelsDir.path);
    if (taskFiles.isNotEmpty) {
      debugPrint('LocalAIService: Found existing model: ${taskFiles.first}');
      return taskFiles.first;
    }

    // Download archive from Kaggle with authentication
    debugPrint('LocalAIService: Downloading archive from Kaggle...');
    final request = http.Request('GET', uri);
    final authHeader = base64Encode(utf8.encode('$username:$apiKey'));
    request.headers['Authorization'] = 'Basic $authHeader';

    final response = await request.send().timeout(
      Duration(minutes: 15), // Kaggle downloads can be large
      onTimeout: () {
        throw Exception('Kaggle download timed out after 15 minutes');
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download from Kaggle: HTTP ${response.statusCode}',
      );
    }

    // Save archive
    final archiveFile = File(archivePath);
    final archiveSink = archiveFile.openWrite();
    await response.stream.forEach((bytes) => archiveSink.add(bytes));
    await archiveSink.close();

    debugPrint('LocalAIService: Archive downloaded, extracting...');

    // Extract tar.gz using system tar command (more reliable than Dart packages)
    if (await extractedDir.exists()) {
      await extractedDir.delete(recursive: true);
    }
    await extractedDir.create(recursive: true);

    final extractResult = await Process.run('tar', [
      '-xzf',
      archivePath,
      '-C',
      extractedDir.path,
    ]);

    if (extractResult.exitCode != 0) {
      throw Exception('Failed to extract archive: ${extractResult.stderr}');
    }

    // Find .task file in extracted directory
    final extractedTaskFiles = await _findTaskFilesInDirectory(
      extractedDir.path,
    );
    if (extractedTaskFiles.isEmpty) {
      throw Exception(
        'No .task file found in extracted archive. '
        'Archive may not contain a MediaPipe model.',
      );
    }

    // Copy .task file to models directory with a clean name
    final finalModelPath = '${modelsDir.path}/$modelName.task';
    await File(extractedTaskFiles.first).copy(finalModelPath);

    // Clean up archive and extracted directory
    try {
      await archiveFile.delete();
      await extractedDir.delete(recursive: true);
    } catch (e) {
      debugPrint('LocalAIService: Warning: Could not clean up: $e');
    }

    debugPrint('LocalAIService: Model extracted and ready: $finalModelPath');

    return finalModelPath;
  }

  /// Find all .task files in a directory recursively
  Future<List<String>> _findTaskFilesInDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      return [];
    }

    final taskFiles = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.task')) {
        taskFiles.add(entity.path);
      }
    }
    return taskFiles;
  }

  /// Download model from URL at runtime (backward compatibility)
  /// Models are cached locally to avoid re-downloading
  Future<String> _downloadModelFromUrl(String url) async {
    final (pathFuture, _) = await downloadModelFromUrl(url);
    return await pathFuture;
  }

  /// Dispose resources
  void dispose() {
    // Cancel any ongoing downloads
    for (final controller in _downloadControllers.values) {
      controller.close();
    }
    _downloadControllers.clear();

    // Mediapipe GenAI engine cleanup
    _llmEngine = null;
    _isInitialized = false;
  }
}
