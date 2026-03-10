import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import 'clipboard_service.dart';
import 'language_detector.dart';
import 'gemini_service.dart';
import 'local_ai_service.dart';
import 'ollama_service.dart';
import 'nobodywho_service.dart';
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
  NobodyWhoService? _nobodyWhoService;
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
  /// Called when a rewrite completes (success or error) so UI (e.g. dashboard) can refresh.
  Function()? onStatsChanged;

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
      _nobodyWhoService = null;
      return;
    }

    if (_config!.modelType == 'ollama') {
      final model = _config!.ollamaModel?.trim();
      if (model == null || model.isEmpty) {
        debugPrint(
          'RewriterService: Ollama model name is required.',
        );
        _localAIService = null;
        _nobodyWhoService = null;
        _aiService = null;
        _geminiService = null;
        return;
      }
      final baseUrl = _config!.ollamaBaseUrl?.trim();
      _aiService = OllamaService(
        baseUrl: (baseUrl == null || baseUrl.isEmpty)
            ? 'http://localhost:11434'
            : baseUrl,
        model: model,
      );
      _localAIService = null;
      _nobodyWhoService = null;
      _geminiService = null;
    } else if (_config!.modelType == 'nobodywho') {
      _nobodyWhoService = NobodyWhoService();
      _aiService = _nobodyWhoService;
      _geminiService = null;
      _localAIService = null;

      _nobodyWhoService!.onStatusChanged = (String status) {
        if (status == 'ready') {
          _onStatusChanged?.call('ready');
        } else if (status == 'error') {
          _onStatusChanged?.call('error');
        } else if (status == 'initializing' || status == 'copying') {
          _onStatusChanged?.call('processing');
        }
      };

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_nobodyWhoService != null && !_nobodyWhoService!.isInitialized) {
          _nobodyWhoService!.initialize().catchError((e, stackTrace) {
            debugPrint('RewriterService: Failed to initialize NobodyWho: $e');
            if (_nobodyWhoService != null &&
                !_nobodyWhoService!.isInitialized) {
              _aiService = null;
            }
            _onStatusChanged?.call('error');
          });
        }
      });
    } else if (_config!.modelType == 'local') {
      if (_config!.modelUrl == null || _config!.modelUrl!.isEmpty) {
        debugPrint(
          'RewriterService: Local AI model URL not configured. '
          'MediaPipe GenAI requires models to be downloaded at runtime.',
        );
        _localAIService = null;
        _nobodyWhoService = null;
        _aiService = null;
        return;
      }

      _localAIService = LocalAIService();
      _aiService = _localAIService;
      _geminiService = null;
      _nobodyWhoService = null;
      
      _localAIService!.onStatusChanged = (String status) {
        if (status == 'ready') {
          _onStatusChanged?.call('ready');
        } else if (status == 'error') {
          _onStatusChanged?.call('error');
        } else if (status == 'downloading' || status == 'initializing') {
          _onStatusChanged?.call('processing');
        }
      };
      
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_localAIService != null && !_localAIService!.isInitialized) {
          _localAIService!.initialize(
            modelUrl: _config!.modelUrl!,
          ).catchError((e, stackTrace) {
            debugPrint('RewriterService: Failed to initialize local AI: $e');
            if (_localAIService != null && !_localAIService!.isInitialized) {
              _aiService = null;
            }
            _onStatusChanged?.call('error');
          });
        }
      });
    } else {
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
      _nobodyWhoService = null;
    }
  }

  /// Get rate limit service (for UI access)
  RateLimitService get rateLimitService => _rateLimitService;

  /// Get local AI service (for UI access to check initialization status)
  LocalAIService? get localAIService => _localAIService;

  /// Get NobodyWho service (for UI access to check initialization status)
  NobodyWhoService? get nobodyWhoService => _nobodyWhoService;

  /// Get history service (for dashboard and history UI)
  HistoryService get historyService => _historyService;

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
    debugPrint('RewriterService: clipboard changed, length=${text.length}');

    if (_config == null || !_config!.enabled) {
      debugPrint('RewriterService: skipped — config null or disabled');
      return;
    }
    if (_isProcessing) {
      debugPrint('RewriterService: skipped — already processing');
      return;
    }
    if (_aiService == null) {
      debugPrint('RewriterService: skipped — aiService is null');
      return;
    }

    // For local AI (MediaPipe), check if it's actually initialized before processing
    if (_config?.modelType == 'local' && _localAIService != null) {
      if (!_localAIService!.isInitialized) {
        debugPrint('RewriterService: skipped — local AI not initialized');
        return;
      }
    }
    // For NobodyWho, check initialization before processing
    if (_config?.modelType == 'nobodywho' && _nobodyWhoService != null) {
      if (!_nobodyWhoService!.isInitialized) {
        debugPrint('RewriterService: skipped — NobodyWho not initialized');
        return;
      }
    }

    debugPrint('RewriterService: scheduling rewrite (debounce=${_config?.debounceMs ?? 1000}ms)');

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
    debugPrint('RewriterService: processClipboardText called, text="${text.length > 60 ? '${text.substring(0, 60)}...' : text}"');
    if (_isProcessing) {
      debugPrint('RewriterService: processClipboardText — already processing');
      return;
    }

    // Check if text is English
    if (!_languageDetector.isEnglish(text)) {
      debugPrint('RewriterService: rejected — not English');
      return;
    }

    // Extract sentences
    final sentences = _languageDetector.extractSentences(text);
    if (sentences.isEmpty) {
      debugPrint('RewriterService: rejected — no sentences');
      return;
    }

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
      debugPrint('RewriterService: rejected — no valid sentences (extracted ${sentences.length} but none passed validation)');
      return;
    }

    // Process first valid sentence (or all if short)
    final textToRewrite = validSentences.length == 1
        ? validSentences.first
        : text;

    if (textToRewrite.length > (_config?.maxSentenceLength ?? 500)) {
      debugPrint('RewriterService: rejected — text too long (${textToRewrite.length} > ${_config?.maxSentenceLength ?? 500})');
      return;
    }

    debugPrint('RewriterService: sending to AI for rewrite (${textToRewrite.length} chars)');
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

      if (result.success) {
        _rewrittenText = _stripThinkTags(result.rewrittenText);

        // Automatically copy to clipboard
        await _clipboardService.setClipboardText(_rewrittenText!);

        // Notify callback
        _onRewrittenTextChanged?.call(_rewrittenText!);
        _onStatusChanged?.call('ready');

        // Save to history (as list for compatibility)
        await _historyService.addToHistory(
          originalText: _lastOriginalText ?? textToRewrite,
          rewrittenTexts: [_rewrittenText!],
          style: _config?.rewriteStyle ?? 'professional',
        );
        await _historyService.recordSuccess();
        onStatsChanged?.call();

        // Show success notification
        await _notificationService.showSuccessNotification(
          _lastOriginalText ?? textToRewrite,
          _rewrittenText!,
        );
      } else {
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
        await _historyService.recordError();
        onStatsChanged?.call();
      }
    } catch (e) {
      debugPrint('RewriterService: Error processing text: $e');
      _onStatusChanged?.call('error');
      await _historyService.recordError();
      onStatsChanged?.call();

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
    if (_config?.modelType == 'local' && config.modelType != 'local') {
      _localAIService?.dispose();
      _localAIService = null;
    }
    if (_config?.modelType == 'nobodywho' && config.modelType != 'nobodywho') {
      _nobodyWhoService?.dispose();
      _nobodyWhoService = null;
    }

    _config = config;
    await _storageService.saveConfig(config);
    _updateAIService();
  }

  /// Start monitoring
  void start() {
    _clipboardService.startMonitoring();
  }

  /// Stop monitoring
  void stop() {
    _clipboardService.stopMonitoring();
    _debounceTimer?.cancel();
  }

  // Strips <think>...</think> blocks and any leading/trailing backticks from AI output.
  static String _stripThinkTags(String text) {
    if (text.isEmpty) return text;
    String s = text.trim();
    // Remove <think>...</think> block (non-greedy, may span newlines)
    const openTag = '<think>';
    const closeTag = '</think>';
    while (true) {
      final start = s.toLowerCase().indexOf(openTag);
      if (start < 0) break;
      final end = s.toLowerCase().indexOf(closeTag, start);
      if (end < 0) break;
      s = (s.substring(0, start) + s.substring(end + closeTag.length)).trim();
    }
    // Trim leading/trailing backticks (e.g. from markdown code blocks)
    while (s.startsWith('`')) { s = s.substring(1).trim(); }
    while (s.endsWith('`')) { s = s.substring(0, s.length - 1).trim(); }
    return s.trim();
  }

  /// Dispose resources
  void dispose() {
    stop();
    _localAIService?.dispose();
    _nobodyWhoService?.dispose();
    _clipboardService.dispose();
  }
}
