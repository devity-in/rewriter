import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import 'clipboard_service.dart';
import 'language_detector.dart';
import 'gemini_service.dart';
import 'local_ai_service.dart';
import 'ai_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'history_service.dart';
import 'rate_limit_service.dart';

/// Main service that orchestrates clipboard monitoring and rewriting
class RewriterService {
  final ClipboardService _clipboardService;
  final LanguageDetector _languageDetector;
  final StorageService _storageService;
  final RateLimitService _rateLimitService;

  AIService? _aiService;
  LocalAIService? _localAIService;
  GeminiService? _geminiService;
  AppConfig? _config;
  Timer? _debounceTimer;
  String? _pendingText;
  bool _isProcessing = false;

  // Store rewritten text (single version)
  String? _rewrittenText;
  String? _lastOriginalText;
  Function(String)? _onRewrittenTextChanged;
  Function(String)?
  _onStatusChanged; // Status: 'idle', 'processing', 'ready', 'error'
  Function(String)? _onOriginalTextChanged; // Callback for original text

  final NotificationService _notificationService = NotificationService();
  final HistoryService _historyService = HistoryService();

  /// Set callback for when original text changes
  set onOriginalTextChanged(Function(String)? callback) {
    _onOriginalTextChanged = callback;
  }

  RewriterService({
    required ClipboardService clipboardService,
    required LanguageDetector languageDetector,
    required StorageService storageService,
    RateLimitService? rateLimitService,
  }) : _clipboardService = clipboardService,
       _languageDetector = languageDetector,
       _storageService = storageService,
       _rateLimitService = rateLimitService ?? RateLimitService() {
    _initialize();
  }

  Future<void> _initialize() async {
    _config = await _storageService.loadConfig();
    _updateAIService();
    _setupClipboardListener();
  }

  void _updateAIService() {
    if (_config == null) {
      _aiService = null;
      _geminiService = null;
      _localAIService = null;
      return;
    }

    if (_config!.modelType == 'local') {
      // Use local AI service (doesn't need API key)
      _localAIService = LocalAIService();
      _aiService = _localAIService;
      _geminiService = null;
      // Initialize local AI service asynchronously
      // Don't block on initialization - let it happen in background
      _localAIService!.initialize(
        modelUrl: _config!.modelUrl,
        kaggleUsername: _config!.kaggleUsername,
        kaggleKey: _config!.kaggleKey,
      ).catchError((e, stackTrace) {
        debugPrint('RewriterService: Failed to initialize local AI: $e');
        debugPrint('Stack trace: $stackTrace');
        // If initialization fails, set service to null so user gets clear error
        if (!_localAIService!.isInitialized) {
          _aiService = null;
          // Check if this is a native assets configuration issue
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('native assets not available') ||
              errorStr.contains('native-assets') ||
              errorStr.contains('symbol not found')) {
            debugPrint(
              'RewriterService: Local AI native assets not configured. '
              'User may need to enable native-assets experiment or switch to Gemini API.',
            );
          }
        }
      });
    } else {
      // Use Gemini service (needs API key)
      if (_config!.isValid) {
        _geminiService = GeminiService(
          apiKey: _config!.apiKey!,
          rateLimitService: _rateLimitService,
        );
        _aiService = _geminiService;
      } else {
        _geminiService = null;
        _aiService = null;
      }
      _localAIService = null;
    }
  }

  /// Get rate limit service (for UI access)
  RateLimitService get rateLimitService => _rateLimitService;

  void _setupClipboardListener() {
    _clipboardService.onClipboardChanged = _handleClipboardChange;
  }

  /// Set callback for when rewritten text is available
  set onRewrittenTextChanged(Function(String)? callback) {
    _onRewrittenTextChanged = callback;
  }

  /// Set callback for when status changes
  set onStatusChanged(Function(String)? callback) {
    _onStatusChanged = callback;
  }

  /// Get current status
  String get status => _isProcessing
      ? 'processing'
      : (_rewrittenText != null ? 'ready' : 'idle');

  /// Get current rewritten text
  String? get rewrittenText => _rewrittenText;

  /// Handle clipboard content change
  void _handleClipboardChange(String text) {
    if (_config == null || !_config!.enabled) {
      debugPrint(
        'RewriterService: Skipping - config=${_config != null}, enabled=${_config?.enabled}',
      );
      return;
    }
    if (_isProcessing) {
      debugPrint('RewriterService: Already processing, skipping');
      return;
    }
    if (_aiService == null) {
      debugPrint(
        'RewriterService: No AI service available (${_config?.modelType == 'local' ? 'Local AI model not initialized' : 'API key not configured'})',
      );
      return;
    }

    // For local AI, check if it's actually initialized before processing
    if (_config?.modelType == 'local' && _localAIService != null) {
      if (!_localAIService!.isInitialized) {
        debugPrint(
          'RewriterService: Local AI service not yet initialized, skipping',
        );
        return;
      }
    }

    debugPrint(
      'RewriterService: Clipboard changed, text length: ${text.length}',
    );

    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Set new debounce timer
    _pendingText = text;
    _debounceTimer = Timer(
      Duration(milliseconds: _config?.debounceMs ?? 1000),
      () => _processClipboardText(_pendingText!),
    );
  }

  /// Process clipboard text
  Future<void> _processClipboardText(String text) async {
    if (_isProcessing) return;

    debugPrint(
      'RewriterService: Processing text: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
    );

    // Check if text is English
    if (!_languageDetector.isEnglish(text)) {
      debugPrint('RewriterService: Text is not English, skipping');
      return;
    }

    // Extract sentences
    final sentences = _languageDetector.extractSentences(text);
    if (sentences.isEmpty) {
      debugPrint('RewriterService: No sentences found, skipping');
      return;
    }

    debugPrint('RewriterService: Found ${sentences.length} sentences');

    // Filter valid sentences
    final validSentences = sentences
        .where(
          (s) => _languageDetector.isValidSentence(
            s,
            minLength: _config?.minSentenceLength ?? 10,
          ),
        )
        .toList();

    if (validSentences.isEmpty) {
      debugPrint('RewriterService: No valid sentences after filtering');
      return;
    }

    // Process first valid sentence (or all if short)
    final textToRewrite = validSentences.length == 1
        ? validSentences.first
        : text;

    if (textToRewrite.length > (_config?.maxSentenceLength ?? 500)) {
      debugPrint(
        'RewriterService: Text too long (${textToRewrite.length} > ${_config?.maxSentenceLength ?? 500})',
      );
      return;
    }

    debugPrint(
      'RewriterService: Sending to ${_config?.modelType ?? 'AI'} API: "${textToRewrite.substring(0, textToRewrite.length > 50 ? 50 : textToRewrite.length)}..."',
    );
    _isProcessing = true;
    _lastOriginalText = textToRewrite;
    _onStatusChanged?.call('processing');
    _onOriginalTextChanged?.call(textToRewrite);

    try {
      // Generate single rewritten version
      final result = await _aiService!.rewriteText(
        textToRewrite,
        style: _config?.rewriteStyle ?? 'professional',
      );

      debugPrint('RewriterService: Received result from API');
      debugPrint('Success: ${result.success}');
      debugPrint('Original: "${result.originalText}"');

      if (result.success) {
        _rewrittenText = result.rewrittenText;
        debugPrint('Rewritten: "$_rewrittenText"');

        // Automatically copy to clipboard
        await _clipboardService.setClipboardText(_rewrittenText!);
        debugPrint(
          'RewriterService: Automatically copied rewritten text to clipboard',
        );

        // Notify callback
        _onRewrittenTextChanged?.call(_rewrittenText!);
        _onStatusChanged?.call('ready');

        // Save to history (as list for compatibility)
        await _historyService.addToHistory(
          originalText: _lastOriginalText ?? textToRewrite,
          rewrittenTexts: [_rewrittenText!],
          style: _config?.rewriteStyle ?? 'professional',
        );

        // Show success notification
        await _notificationService.showSuccessNotification(
          _lastOriginalText ?? textToRewrite,
          _rewrittenText!,
        );
      } else {
        debugPrint('Error: ${result.error}');
        _rewrittenText = null;
        _onStatusChanged?.call('error');

        // Check error type and provide appropriate message
        final errorStr = result.error?.toLowerCase() ?? '';
        final isRateLimit = errorStr.contains('rate limit');
        final isNativeAssetsError =
            errorStr.contains('native assets not available') ||
            errorStr.contains('native-assets') ||
            errorStr.contains('couldn\'t resolve native');

        String errorMessage;
        if (isNativeAssetsError) {
          errorMessage =
              'Local AI native assets not configured. '
              'Enable native-assets: `flutter config --enable-native-assets`, then rebuild. '
              'Or switch to Gemini API in settings.';
        } else if (isRateLimit) {
          errorMessage = 'Rate limit reached. Please wait before trying again.';
        } else {
          errorMessage =
              'Failed to rewrite text. Check API key and connection.';
        }

        // Show error notification
        await _notificationService.showErrorNotification(errorMessage);
      }
    } catch (e) {
      debugPrint('RewriterService: Error processing text: $e');
      _onStatusChanged?.call('error');

      // Show error notification
      final errorMsg = e.toString().length > 100
          ? '${e.toString().substring(0, 97)}...'
          : e.toString();
      await _notificationService.showErrorNotification(errorMsg);
    } finally {
      _isProcessing = false;
    }
  }

  /// Update configuration
  Future<void> updateConfig(AppConfig config) async {
    // Dispose old local AI service if switching away from it
    if (_config?.modelType == 'local' && config.modelType != 'local') {
      _localAIService?.dispose();
      _localAIService = null;
    }

    _config = config;
    await _storageService.saveConfig(config);
    _updateAIService();
  }

  /// Start monitoring
  void start() {
    debugPrint('RewriterService: Starting clipboard monitoring');
    _clipboardService.startMonitoring();
  }

  /// Stop monitoring
  void stop() {
    debugPrint('RewriterService: Stopping clipboard monitoring');
    _clipboardService.stopMonitoring();
    _debounceTimer?.cancel();
  }

  /// Dispose resources
  void dispose() {
    stop();
    _localAIService?.dispose();
    _clipboardService.dispose();
  }
}
