import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:clipboard/clipboard.dart';

/// Service for monitoring and managing clipboard
class ClipboardService {
  String? _lastClipboardContent;
  Timer? _monitoringTimer;
  Function(String)? _onClipboardChanged;

  ClipboardService({Function(String)? onClipboardChanged})
    : _onClipboardChanged = onClipboardChanged;

  /// Set clipboard change callback
  set onClipboardChanged(Function(String)? callback) {
    _onClipboardChanged = callback;
  }

  /// Start monitoring clipboard changes
  void startMonitoring({int intervalMs = 500}) {
    stopMonitoring();
    debugPrint(
      'ClipboardService: Starting monitoring (interval: ${intervalMs}ms)',
    );

    _monitoringTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _checkClipboard(),
    );
  }

  /// Stop monitoring clipboard changes
  void stopMonitoring() {
    debugPrint('ClipboardService: Stopping monitoring');
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// Check clipboard for changes
  Future<void> _checkClipboard() async {
    try {
      final currentContent = await FlutterClipboard.paste();

      if (currentContent.isNotEmpty &&
          currentContent != _lastClipboardContent &&
          currentContent.trim().isNotEmpty) {
        debugPrint(
          'ClipboardService: Clipboard changed (length: ${currentContent.length})',
        );
        _lastClipboardContent = currentContent;
        _onClipboardChanged?.call(currentContent);
      }
    } catch (e) {
      // Silently handle clipboard access errors
    }
  }

  /// Get current clipboard content
  Future<String?> getClipboardText() async {
    try {
      return await FlutterClipboard.paste();
    } catch (e) {
      return null;
    }
  }

  /// Set clipboard content
  Future<bool> setClipboardText(String text) async {
    try {
      await FlutterClipboard.copy(text);
      _lastClipboardContent = text;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
  }
}
