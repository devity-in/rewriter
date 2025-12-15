import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for showing system notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _notifications;
  bool _initialized = false;
  String? _iconPath;
  
  // Callbacks for notification actions
  Function(String)? onCopyText;
  Function()? onCloseNotification;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    _notifications = FlutterLocalNotificationsPlugin();

    // Prepare icon path for macOS notifications
    if (Platform.isMacOS) {
      try {
        // Load icon from assets and save to a temporary location for notifications
        final ByteData data = await rootBundle.load('assets/icon.png');
        final String homeDir = Platform.environment['HOME'] ?? '/tmp';
        final String iconDir = '$homeDir/.rewriter';
        final Directory dir = Directory(iconDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final File iconFile = File('$iconDir/notification_icon.png');
        await iconFile.writeAsBytes(data.buffer.asUint8List());
        _iconPath = iconFile.path;
        debugPrint('Notification icon prepared at: $_iconPath');
      } catch (e) {
        debugPrint('Warning: Could not prepare notification icon: $e');
        // Continue without custom icon - macOS will use app icon
      }
    }

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

  /// Handle notification tap and actions
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: id=${response.id}, actionId=${response.actionId}, payload=${response.payload}');
    
    // Text is already copied, but user can tap to copy again if needed
    if (response.id == 2 && response.payload != null && response.payload!.isNotEmpty) {
      onCopyText?.call(response.payload!);
    }
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
  /// Text is already copied to clipboard, notification shows the rewritten text
  Future<void> showSuccessNotification(
    String originalText,
    String rewrittenText,
  ) async {
    if (!_initialized || _notifications == null) return;

    // Truncate text if too long for notification
    final displayText = rewrittenText.length > 200
        ? '${rewrittenText.substring(0, 197)}...'
        : rewrittenText;

    // Create notification details for macOS
    final macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'REWRITE_READY',
    );

    final details = NotificationDetails(macOS: macOSDetails);

    // Show notification with rewritten text
    await _notifications!.show(
      2,
      'Rewriter',
      displayText,
      details,
      payload: rewrittenText, // Store full text in payload
    );
    
    debugPrint('Success notification shown. Text already copied: "$rewrittenText"');
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

