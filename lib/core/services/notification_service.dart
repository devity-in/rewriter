import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for showing system notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _notifications;
  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    _notifications = FlutterLocalNotificationsPlugin();

    // macOS-specific initialization
    if (Platform.isMacOS) {
      const macOSInitializationSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        macOS: macOSInitializationSettings,
      );

      await _notifications!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions
      await _notifications!
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    _initialized = true;
    debugPrint('NotificationService: Initialized');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.id}');
    // Can be extended to handle specific actions
  }

  /// Show notification when rewrite starts
  Future<void> showProcessingNotification(String originalText) async {
    if (!_initialized || _notifications == null) return;

    final truncatedText = originalText.length > 50
        ? '${originalText.substring(0, 47)}...'
        : originalText;

    const macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(macOS: macOSDetails);

    await _notifications!.show(
      1,
      'Rewriter',
      'Processing: "$truncatedText"',
      details,
    );
  }

  /// Show notification when rewrite completes
  Future<void> showSuccessNotification(
    String originalText,
    int versionCount,
  ) async {
    if (!_initialized || _notifications == null) return;

    final truncatedText = originalText.length > 50
        ? '${originalText.substring(0, 47)}...'
        : originalText;

    const macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(macOS: macOSDetails);

    await _notifications!.show(
      2,
      'Rewriter',
      '$versionCount version${versionCount > 1 ? 's' : ''} ready for "$truncatedText"',
      details,
    );
  }

  /// Show error notification
  Future<void> showErrorNotification(String errorMessage) async {
    if (!_initialized || _notifications == null) return;

    const macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(macOS: macOSDetails);

    await _notifications!.show(
      3,
      'Rewriter Error',
      errorMessage,
      details,
    );
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    if (_notifications != null) {
      await _notifications!.cancelAll();
    }
  }
}

