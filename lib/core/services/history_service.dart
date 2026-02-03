import 'dart:convert';
import 'package:flutter/material.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewrite_history_item.dart';

/// Service for managing rewrite history and success/error stats
class HistoryService {
  static const String _historyKey = 'rewrite_history';
  static const String _dailyStatsKey = 'daily_rewrite_stats'; // date string -> { success, error }
  static const String _hourlyStatsKey = 'hourly_rewrite_stats'; // date string -> hour "0".."23" -> { success, error }
  static const int _maxHistoryItems = 50; // Keep last 50 items
  static const int _maxStatsDays = 60; // Keep last 60 days of stats

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
      debugPrint('Error saving history: $e');
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
      debugPrint('Error loading history: $e');
      return [];
    }
  }

  /// Clear all history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }

  /// Get recent rewrites for menu (last 5)
  Future<List<RewriteHistoryItem>> getRecentRewrites() async {
    return await getHistory(limit: 5);
  }

  /// Total number of items in history (capped at [_maxHistoryItems])
  Future<int> getTotalCount() async {
    final list = await getHistory(limit: _maxHistoryItems);
    return list.length;
  }

  /// Number of rewrites done today
  Future<int> getTodayCount() async {
    final list = await getHistory(limit: _maxHistoryItems);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return list.where((item) {
      final t = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
      return t == today;
    }).length;
  }

  /// Rewrites count per day for the last [days] days (oldest first).
  /// Each entry is (date, count). Days with no rewrites have count 0.
  Future<List<({DateTime date, int count})>> getRewritesByDay(int days) async {
    final list = await getHistory(limit: _maxHistoryItems);
    final now = DateTime.now();
    final result = <({DateTime date, int count})>[];
    for (var i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final count = list.where((item) {
        final t = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
        return t == date;
      }).length;
      result.add((date: date, count: count));
    }
    return result;
  }

  /// Record a successful rewrite (for stats).
  Future<void> recordSuccess() async {
    await _incrementStat(true);
  }

  /// Record a failed rewrite (for stats).
  Future<void> recordError() async {
    await _incrementStat(false);
  }

  Future<void> _incrementStat(bool success) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final hourKey = '${now.hour}';

      // Daily stats
      final json = prefs.getString(_dailyStatsKey);
      final Map<String, dynamic> map = json != null
          ? Map<String, dynamic>.from(jsonDecode(json) as Map)
          : {};
      final current = map[dateKey] as Map<String, dynamic>? ?? {};
      final s = (current['success'] as int?) ?? 0;
      final e = (current['error'] as int?) ?? 0;
      if (success) {
        map[dateKey] = {'success': s + 1, 'error': e};
      } else {
        map[dateKey] = {'success': s, 'error': e + 1};
      }
      final keys = map.keys.toList()..sort();
      if (keys.length > _maxStatsDays) {
        for (var i = 0; i < keys.length - _maxStatsDays; i++) {
          map.remove(keys[i]);
        }
      }
      await prefs.setString(_dailyStatsKey, jsonEncode(map));

      // Hourly stats for today (for 1-day chart by time)
      final hourlyJson = prefs.getString(_hourlyStatsKey);
      final Map<String, dynamic> hourlyByDate = hourlyJson != null
          ? Map<String, dynamic>.from(jsonDecode(hourlyJson) as Map)
          : {};
      final hourMap = hourlyByDate[dateKey] as Map<String, dynamic>? ?? {};
      final hourCurrent = hourMap[hourKey] as Map<String, dynamic>? ?? {};
      final hs = (hourCurrent['success'] as int?) ?? 0;
      final he = (hourCurrent['error'] as int?) ?? 0;
      if (success) {
        hourMap[hourKey] = {'success': hs + 1, 'error': he};
      } else {
        hourMap[hourKey] = {'success': hs, 'error': he + 1};
      }
      hourlyByDate[dateKey] = hourMap;
      // Keep only today and yesterday to limit storage
      final toRemove = hourlyByDate.keys.where((k) => k != dateKey).toList();
      for (final k in toRemove) {
        hourlyByDate.remove(k);
      }
      await prefs.setString(_hourlyStatsKey, jsonEncode(hourlyByDate));
    } catch (e) {
      debugPrint('Error recording stat: $e');
    }
  }

  /// Success and error counts per day for the last [days] days (oldest first).
  /// When [days] == 1, returns 24 entries by hour for today (data by time).
  Future<List<({DateTime date, int success, int error})>> getStatsByDay(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (days == 1) {
        // 1-day view: return 24 hourly buckets for today (by time)
        final hourlyJson = prefs.getString(_hourlyStatsKey);
        final Map<String, dynamic> hourlyByDate = hourlyJson != null
            ? Map<String, dynamic>.from(jsonDecode(hourlyJson) as Map)
            : {};
        final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final hourMap = hourlyByDate[dateKey] as Map<String, dynamic>? ?? {};
        final result = <({DateTime date, int success, int error})>[];
        for (var h = 0; h < 24; h++) {
          final bucket = hourMap['$h'] as Map<String, dynamic>? ?? {};
          final success = (bucket['success'] as int?) ?? 0;
          final error = (bucket['error'] as int?) ?? 0;
          result.add((
            date: DateTime(today.year, today.month, today.day, h),
            success: success,
            error: error,
          ));
        }
        return result;
      }

      // 7 or 30 days: per-day stats
      final json = prefs.getString(_dailyStatsKey);
      final Map<String, dynamic> map = json != null
          ? Map<String, dynamic>.from(jsonDecode(json) as Map)
          : {};
      final result = <({DateTime date, int success, int error})>[];
      for (var i = days - 1; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final current = map[dateKey] as Map<String, dynamic>? ?? {};
        final success = (current['success'] as int?) ?? 0;
        final error = (current['error'] as int?) ?? 0;
        result.add((date: date, success: success, error: error));
      }
      return result;
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return [];
    }
  }
}
