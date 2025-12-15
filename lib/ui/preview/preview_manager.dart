import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/services/clipboard_service.dart';

/// Manages the preview window lifecycle
class PreviewManager {
  final ClipboardService clipboardService;
  bool _isShowing = false;
  bool _isLoading = false;
  String? _currentOriginalText;
  List<String> _currentRewrittenTexts = [];

  PreviewManager({required this.clipboardService});

  /// Show preview window with loading state
  Future<void> showPreviewLoading({required String originalText}) async {
    try {
      _currentOriginalText = originalText;
      _currentRewrittenTexts = [];
      _isLoading = true;
      _isShowing = true;

      // Show the main window with preview content
      await windowManager.setSize(const Size(500, 500));
      await _positionWindow();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Error showing preview window (loading): $e');
      _isShowing = false;
      _isLoading = false;
    }
  }

  /// Show preview window with rewritten texts
  Future<void> showPreview({
    required String originalText,
    required List<String> rewrittenTexts,
  }) async {
    try {
      _currentOriginalText = originalText;
      _currentRewrittenTexts = rewrittenTexts;
      _isLoading = false;
      _isShowing = true;

      // Calculate optimal window size based on content
      final estimatedHeight = 200 + (rewrittenTexts.length * 150) + 100;
      final height = estimatedHeight.clamp(400, 800).toDouble();
      
      await windowManager.setSize(Size(600, height));
      await _positionWindow();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Error showing preview window: $e');
      // Don't throw - gracefully handle the error
      _isShowing = false;
      _isLoading = false;
    }
  }

  /// Position window near cursor or center
  Future<void> _positionWindow() async {
    try {
      // Position window in center
      // Future enhancement: could position near cursor or active window
      await windowManager.center();
    } catch (e) {
      // Fallback to center if positioning fails
      debugPrint('Error positioning window, centering: $e');
      await windowManager.center();
    }
  }

  /// Hide preview window
  Future<void> hidePreview() async {
    _isShowing = false;
    await windowManager.hide();
  }

  bool get isShowing => _isShowing;
  bool get isLoading => _isLoading;
  String? get currentOriginalText => _currentOriginalText;
  List<String> get currentRewrittenTexts => _currentRewrittenTexts;
}
