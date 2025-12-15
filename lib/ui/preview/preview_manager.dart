import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/services/clipboard_service.dart';

/// Manages the preview window lifecycle
class PreviewManager {
  final ClipboardService clipboardService;
  bool _isShowing = false;
  String? _currentOriginalText;
  List<String> _currentRewrittenTexts = [];

  PreviewManager({required this.clipboardService});

  /// Show preview window with rewritten texts
  Future<void> showPreview({
    required String originalText,
    required List<String> rewrittenTexts,
  }) async {
    try {
      _currentOriginalText = originalText;
      _currentRewrittenTexts = rewrittenTexts;
      _isShowing = true;

      // Show the main window with preview content
      await windowManager.setSize(const Size(500, 400));
      await windowManager.center();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Error showing preview window: $e');
      // Don't throw - gracefully handle the error
      _isShowing = false;
    }
  }

  /// Hide preview window
  Future<void> hidePreview() async {
    _isShowing = false;
    await windowManager.hide();
  }

  bool get isShowing => _isShowing;
  String? get currentOriginalText => _currentOriginalText;
  List<String> get currentRewrittenTexts => _currentRewrittenTexts;
}
