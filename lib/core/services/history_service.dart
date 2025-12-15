import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewrite_history_item.dart';

/// Service for managing rewrite history
class HistoryService {
  static const String _historyKey = 'rewrite_history';
  static const int _maxHistoryItems = 50; // Keep last 50 items

  /// Save a rewrite to history
  Future<void> addToHistory({
    required String originalText,
    required List<String> rewrittenTexts,
    required String style,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];
      
      final item = RewriteHistoryItem(
        originalText: originalText,
        rewrittenTexts: rewrittenTexts,
        timestamp: DateTime.now(),
        style: style,
      );

      // Add to beginning of list
      historyJson.insert(0, jsonEncode(item.toJson()));

      // Keep only last N items
      if (historyJson.length > _maxHistoryItems) {
        historyJson.removeRange(_maxHistoryItems, historyJson.length);
      }

      await prefs.setStringList(_historyKey, historyJson);
    } catch (e) {
      // Silently handle errors - history is not critical
      print('Error saving history: $e');
    }
  }

  /// Get rewrite history
  Future<List<RewriteHistoryItem>> getHistory({int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_historyKey) ?? [];

      final history = historyJson
          .take(limit)
          .map((jsonStr) {
            try {
              return RewriteHistoryItem.fromJson(jsonDecode(jsonStr));
            } catch (e) {
              return null;
            }
          })
          .whereType<RewriteHistoryItem>()
          .toList();

      return history;
    } catch (e) {
      print('Error loading history: $e');
      return [];
    }
  }

  /// Clear all history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  /// Get recent rewrites for menu (last 5)
  Future<List<RewriteHistoryItem>> getRecentRewrites() async {
    return await getHistory(limit: 5);
  }
}




