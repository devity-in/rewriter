import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import 'clipboard_service.dart';
import 'language_detector.dart';
import 'gemini_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'history_service.dart';

/// Main service that orchestrates clipboard monitoring and rewriting
class RewriterService {
  final ClipboardService _clipboardService;
  final LanguageDetector _languageDetector;
  final StorageService _storageService;

  GeminiService? _geminiService;
  AppConfig? _config;
  Timer? _debounceTimer;
  String? _pendingText;
  bool _isProcessing = false;

  // Store rewritten texts for tray menu
  List<String> _rewrittenTexts = [];
  String? _lastOriginalText;
  Function(List<String>)? _onRewrittenTextsChanged;
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
  }) : _clipboardService = clipboardService,
       _languageDetector = languageDetector,
       _storageService = storageService {
    _initialize();
  }

  Future<void> _initialize() async {
    _config = await _storageService.loadConfig();
    _updateGeminiService();
    _setupClipboardListener();
  }

  void _updateGeminiService() {
    if (_config?.isValid == true) {
      _geminiService = GeminiService(apiKey: _config!.apiKey!);
    } else {
      _geminiService = null;
    }
  }

  void _setupClipboardListener() {
    _clipboardService.onClipboardChanged = _handleClipboardChange;
  }

  /// Set callback for when rewritten texts are available
  set onRewrittenTextsChanged(Function(List<String>)? callback) {
    _onRewrittenTextsChanged = callback;
  }

  /// Set callback for when status changes
  set onStatusChanged(Function(String)? callback) {
    _onStatusChanged = callback;
  }

  /// Get current status
  String get status => _isProcessing
      ? 'processing'
      : (_rewrittenTexts.isNotEmpty ? 'ready' : 'idle');

  /// Get current rewritten texts
  List<String> get rewrittenTexts => List.unmodifiable(_rewrittenTexts);

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
    if (_geminiService == null) {
      debugPrint(
        'RewriterService: No Gemini service available (API key not configured)',
      );
      return;
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
      'RewriterService: Sending to Gemini API: "${textToRewrite.substring(0, textToRewrite.length > 50 ? 50 : textToRewrite.length)}..."',
    );
    _isProcessing = true;
    _lastOriginalText = textToRewrite;
    _onStatusChanged?.call('processing');
    _onOriginalTextChanged?.call(textToRewrite);

    // Show processing notification
    await _notificationService.showProcessingNotification(textToRewrite);

    try {
      // Generate 2 rewritten versions
      final results = await _geminiService!.rewriteTextMultiple(
        textToRewrite,
        style: _config?.rewriteStyle ?? 'professional',
      );

      debugPrint(
        'RewriterService: Received ${results.length} results from API',
      );

      // Print detailed results
      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        debugPrint('--- Result ${i + 1} ---');
        debugPrint('Success: ${result.success}');
        debugPrint('Original: "${result.originalText}"');
        if (result.success) {
          debugPrint('Rewritten: "${result.rewrittenText}"');
        } else {
          debugPrint('Error: ${result.error}');
        }
        debugPrint('---');
      }

      // Store successful rewritten texts (up to 2)
      _rewrittenTexts = results
          .where((r) => r.success)
          .take(2)
          .map((r) => r.rewrittenText)
          .toList();

      debugPrint(
        'RewriterService: Successfully rewritten ${_rewrittenTexts.length} versions',
      );
      for (int i = 0; i < _rewrittenTexts.length; i++) {
        debugPrint('  Version ${i + 1}: "${_rewrittenTexts[i]}"');
      }

      // Notify tray manager of new rewritten texts
      if (_rewrittenTexts.isNotEmpty) {
        _onRewrittenTextsChanged?.call(_rewrittenTexts);
        _onStatusChanged?.call('ready');

        // Save to history
        await _historyService.addToHistory(
          originalText: _lastOriginalText ?? textToRewrite,
          rewrittenTexts: _rewrittenTexts,
          style: _config?.rewriteStyle ?? 'professional',
        );

        // Show success notification
        await _notificationService.showSuccessNotification(
          _lastOriginalText ?? textToRewrite,
          _rewrittenTexts.length,
        );
      } else {
        debugPrint(
          'RewriterService: No successful rewrites, not updating tray menu',
        );
        _onStatusChanged?.call('error');

        // Show error notification
        await _notificationService.showErrorNotification(
          'Failed to rewrite text. Check API key and connection.',
        );
      }

      // Don't automatically copy to clipboard - let user choose from menu
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
    _config = config;
    await _storageService.saveConfig(config);
    _updateGeminiService();
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
    _clipboardService.dispose();
  }
}
