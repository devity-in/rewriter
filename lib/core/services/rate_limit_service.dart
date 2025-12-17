import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking API usage and enforcing rate limits
class RateLimitService {
  static const String _requestsKey = 'rate_limit_requests';
  static const String _windowStartKey = 'rate_limit_window_start';
  static const String _totalRequestsKey = 'rate_limit_total_requests';
  static const String _lastWarningKey = 'rate_limit_last_warning';

  // Default limits (can be configured)
  int _maxRequestsPerMinute = 60; // 60 requests per minute
  int _maxRequestsPerHour = 1000; // 1000 requests per hour
  int _maxRequestsPerDay = 15000; // 15000 requests per day

  // Warning thresholds (show warning at 80% of limit)
  double _warningThreshold = 0.8;

  RateLimitService();

  /// Configure rate limits
  void configure({
    int? maxRequestsPerMinute,
    int? maxRequestsPerHour,
    int? maxRequestsPerDay,
    double? warningThreshold,
  }) {
    if (maxRequestsPerMinute != null) {
      _maxRequestsPerMinute = maxRequestsPerMinute;
    }
    if (maxRequestsPerHour != null) _maxRequestsPerHour = maxRequestsPerHour;
    if (maxRequestsPerDay != null) _maxRequestsPerDay = maxRequestsPerDay;
    if (warningThreshold != null) _warningThreshold = warningThreshold;
  }

  /// Check if a request can be made (rate limit check)
  Future<RateLimitResult> canMakeRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Get current request counts
    final requestsPerMinute = await _getRequestsInWindow(
      prefs,
      now,
      Duration(minutes: 1),
    );
    final requestsPerHour = await _getRequestsInWindow(
      prefs,
      now,
      Duration(hours: 1),
    );
    final requestsPerDay = await _getRequestsInWindow(
      prefs,
      now,
      Duration(days: 1),
    );

    // Check limits
    if (requestsPerMinute >= _maxRequestsPerMinute) {
      return RateLimitResult(
        allowed: false,
        reason: RateLimitReason.perMinuteLimit,
        retryAfter: Duration(minutes: 1),
        currentCount: requestsPerMinute,
        limit: _maxRequestsPerMinute,
      );
    }

    if (requestsPerHour >= _maxRequestsPerHour) {
      return RateLimitResult(
        allowed: false,
        reason: RateLimitReason.perHourLimit,
        retryAfter: Duration(hours: 1),
        currentCount: requestsPerHour,
        limit: _maxRequestsPerHour,
      );
    }

    if (requestsPerDay >= _maxRequestsPerDay) {
      return RateLimitResult(
        allowed: false,
        reason: RateLimitReason.perDayLimit,
        retryAfter: Duration(days: 1),
        currentCount: requestsPerDay,
        limit: _maxRequestsPerDay,
      );
    }

    // Check if we should show warnings
    final shouldWarn = _shouldShowWarning(
      requestsPerMinute,
      requestsPerHour,
      requestsPerDay,
    );

    return RateLimitResult(
      allowed: true,
      reason: RateLimitReason.none,
      currentCount: requestsPerDay,
      limit: _maxRequestsPerDay,
      shouldWarn: shouldWarn,
      warningMessage: shouldWarn
          ? _getWarningMessage(
              requestsPerMinute,
              requestsPerHour,
              requestsPerDay,
            )
          : null,
    );
  }

  /// Record a successful API request
  Future<void> recordRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Get existing requests list
    final requestsJson = prefs.getStringList(_requestsKey) ?? [];
    final requests = requestsJson
        .map((json) => DateTime.parse(json))
        .where(
          (timestamp) => now.difference(timestamp).inDays < 2,
        ) // Keep only last 2 days
        .toList();

    // Add current request
    requests.add(now);

    // Save back
    await prefs.setStringList(
      _requestsKey,
      requests.map((d) => d.toIso8601String()).toList(),
    );

    // Update total count
    final totalRequests = prefs.getInt(_totalRequestsKey) ?? 0;
    await prefs.setInt(_totalRequestsKey, totalRequests + 1);

    debugPrint(
      'RateLimitService: Recorded request. Total: ${totalRequests + 1}',
    );
  }

  /// Get request count in a time window
  Future<int> _getRequestsInWindow(
    SharedPreferences prefs,
    DateTime now,
    Duration window,
  ) async {
    final requestsJson = prefs.getStringList(_requestsKey) ?? [];
    final requests = requestsJson.map((json) => DateTime.parse(json)).toList();

    final windowStart = now.subtract(window);
    return requests.where((timestamp) => timestamp.isAfter(windowStart)).length;
  }

  /// Get current usage statistics
  Future<RateLimitStats> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final requestsPerMinute = await _getRequestsInWindow(
      prefs,
      now,
      Duration(minutes: 1),
    );
    final requestsPerHour = await _getRequestsInWindow(
      prefs,
      now,
      Duration(hours: 1),
    );
    final requestsPerDay = await _getRequestsInWindow(
      prefs,
      now,
      Duration(days: 1),
    );
    final totalRequests = prefs.getInt(_totalRequestsKey) ?? 0;

    return RateLimitStats(
      requestsPerMinute: requestsPerMinute,
      requestsPerHour: requestsPerHour,
      requestsPerDay: requestsPerDay,
      totalRequests: totalRequests,
      maxRequestsPerMinute: _maxRequestsPerMinute,
      maxRequestsPerHour: _maxRequestsPerHour,
      maxRequestsPerDay: _maxRequestsPerDay,
    );
  }

  /// Check if we should show a warning
  bool _shouldShowWarning(
    int requestsPerMinute,
    int requestsPerHour,
    int requestsPerDay,
  ) {
    final minuteThreshold = (_maxRequestsPerMinute * _warningThreshold).round();
    final hourThreshold = (_maxRequestsPerHour * _warningThreshold).round();
    final dayThreshold = (_maxRequestsPerDay * _warningThreshold).round();

    return requestsPerMinute >= minuteThreshold ||
        requestsPerHour >= hourThreshold ||
        requestsPerDay >= dayThreshold;
  }

  /// Get warning message
  String _getWarningMessage(
    int requestsPerMinute,
    int requestsPerHour,
    int requestsPerDay,
  ) {
    final minuteThreshold = (_maxRequestsPerMinute * _warningThreshold).round();
    final hourThreshold = (_maxRequestsPerHour * _warningThreshold).round();
    final dayThreshold = (_maxRequestsPerDay * _warningThreshold).round();

    if (requestsPerDay >= dayThreshold) {
      final percentage = (requestsPerDay / _maxRequestsPerDay * 100).round();
      return 'High daily usage: $requestsPerDay/$_maxRequestsPerDay ($percentage%)';
    }
    if (requestsPerHour >= hourThreshold) {
      final percentage = (requestsPerHour / _maxRequestsPerHour * 100).round();
      return 'High hourly usage: $requestsPerHour/$_maxRequestsPerHour ($percentage%)';
    }
    if (requestsPerMinute >= minuteThreshold) {
      final percentage = (requestsPerMinute / _maxRequestsPerMinute * 100)
          .round();
      return 'High usage rate: $requestsPerMinute/$_maxRequestsPerMinute per minute ($percentage%)';
    }
    return '';
  }

  /// Reset all rate limit data (for testing)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestsKey);
    await prefs.remove(_windowStartKey);
    await prefs.remove(_totalRequestsKey);
    await prefs.remove(_lastWarningKey);
    debugPrint('RateLimitService: Reset all rate limit data');
  }

  /// Clear old request data (keep only last 2 days)
  Future<void> cleanup() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final requestsJson = prefs.getStringList(_requestsKey) ?? [];
    final requests = requestsJson
        .map((json) => DateTime.parse(json))
        .where((timestamp) => now.difference(timestamp).inDays < 2)
        .toList();

    await prefs.setStringList(
      _requestsKey,
      requests.map((d) => d.toIso8601String()).toList(),
    );
  }
}

/// Result of rate limit check
class RateLimitResult {
  final bool allowed;
  final RateLimitReason reason;
  final Duration? retryAfter;
  final int currentCount;
  final int limit;
  final bool shouldWarn;
  final String? warningMessage;

  RateLimitResult({
    required this.allowed,
    required this.reason,
    this.retryAfter,
    required this.currentCount,
    required this.limit,
    this.shouldWarn = false,
    this.warningMessage,
  });

  double get usagePercentage => (currentCount / limit * 100).clamp(0.0, 100.0);
}

/// Reason for rate limiting
enum RateLimitReason { none, perMinuteLimit, perHourLimit, perDayLimit }

/// Rate limit statistics
class RateLimitStats {
  final int requestsPerMinute;
  final int requestsPerHour;
  final int requestsPerDay;
  final int totalRequests;
  final int maxRequestsPerMinute;
  final int maxRequestsPerHour;
  final int maxRequestsPerDay;

  RateLimitStats({
    required this.requestsPerMinute,
    required this.requestsPerHour,
    required this.requestsPerDay,
    required this.totalRequests,
    required this.maxRequestsPerMinute,
    required this.maxRequestsPerHour,
    required this.maxRequestsPerDay,
  });

  double get minuteUsagePercentage =>
      (requestsPerMinute / maxRequestsPerMinute * 100).clamp(0.0, 100.0);
  double get hourUsagePercentage =>
      (requestsPerHour / maxRequestsPerHour * 100).clamp(0.0, 100.0);
  double get dayUsagePercentage =>
      (requestsPerDay / maxRequestsPerDay * 100).clamp(0.0, 100.0);
}
