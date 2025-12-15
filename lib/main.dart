import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'core/services/storage_service.dart';
import 'core/services/clipboard_service.dart';
import 'core/services/language_detector.dart';
import 'core/services/rewriter_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/hotkey_service.dart';
import 'ui/providers/app_provider.dart';
import 'ui/tray/tray_manager.dart';
import 'ui/settings/settings_page.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize window manager for desktop
    await windowManager.ensureInitialized();

    // Set window options for system tray app
    const windowOptions = WindowOptions(
      skipTaskbar: true,
      backgroundColor: Colors.transparent,
    );

    await windowManager.waitUntilReadyToShow(windowOptions);

    // Hide window immediately - it's a system tray app
    try {
      await windowManager.hide();
    } catch (e) {
      debugPrint('Note: Window hide called early: $e');
    }

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Initialize hotkey service
    final hotkeyService = HotkeyService();

    // Initialize services
    final storageService = StorageService();
    final clipboardService = ClipboardService();
    final languageDetector = LanguageDetector();
    final rewriterService = RewriterService(
      clipboardService: clipboardService,
      languageDetector: languageDetector,
      storageService: storageService,
    );

    // Initialize app provider
    final appProvider = AppProvider(
      storageService: storageService,
      rewriterService: rewriterService,
    );

    // Initialize tray manager - simplified
    final trayManager = TrayManager(
      onSettingsClick: () async {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (e) {
          debugPrint('Error showing settings window: $e');
        }
      },
      onQuitClick: () {
        windowManager.close();
      },
      onToggleClick: () {
        appProvider.toggleEnabled();
      },
    );

    // Connect rewriter service to tray manager and notifications
    String? lastRewrittenText;

    // Setup notification callbacks
    notificationService.onCopyText = (String text) async {
      await clipboardService.setClipboardText(text);
      debugPrint('Copied to clipboard from notification: $text');
      // Dismiss notification after copy
      await notificationService.cancelAll();
    };

    notificationService.onCloseNotification = () async {
      await notificationService.cancelAll();
      debugPrint('Notification dismissed');
    };

    // Track rewritten text (single version)
    rewriterService.onRewrittenTextChanged = (String text) {
      debugPrint('Rewritten text available: "$text"');
      lastRewrittenText = text;
      // Text is already copied to clipboard by rewriter service
    };

    // Track status changes
    rewriterService.onStatusChanged = (String status) {
      debugPrint('Status changed: $status');
      trayManager.updateStatus(status);
    };

    // Setup hotkey callbacks - copy current rewritten text if available
    hotkeyService.onCopyRewritten = () async {
      if (lastRewrittenText != null) {
        await clipboardService.setClipboardText(lastRewrittenText!);
        debugPrint('Copied rewritten text via hotkey');
      }
    };

    hotkeyService.onShowSettings = () async {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (e) {
        debugPrint('Error showing settings via hotkey: $e');
      }
    };

    hotkeyService.onToggleEnabled = () {
      appProvider.toggleEnabled();
    };

    // Initialize hotkeys
    await hotkeyService.initialize();

    // Initialize tray manager with error handling
    try {
      await trayManager.initialize();
      debugPrint('Tray manager initialized successfully');

      // Wait for app provider to initialize, then set initial menu state
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (appProvider.isInitialized) {
          await trayManager.updateMenu(appProvider.isEnabled);
        }
      });

      // Listen to enabled state changes and update tray menu
      appProvider.addListener(() {
        if (appProvider.isInitialized) {
          trayManager.updateMenu(appProvider.isEnabled);
        }
      });
    } catch (e) {
      debugPrint('Error initializing tray manager: $e');
      // Continue anyway - app can run without tray
    }

    // Run the app first
    runApp(
      ChangeNotifierProvider.value(
        value: appProvider,
        child: const RewriterApp(),
      ),
    );

    // Hide window after app is running (delay to ensure app is fully initialized)
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        await windowManager.hide();
        debugPrint('Window hidden successfully');
        debugPrint(
          'App is running in background. Check menu bar for tray icon.',
        );
      } catch (e) {
        debugPrint('Error hiding window: $e');
      }
    });

    // Keep app alive - prevent it from exiting
    // This is important for system tray apps
    debugPrint('App initialized. Running in background...');
  } catch (e, stackTrace) {
    // Log error but don't crash - system tray apps should be resilient
    debugPrint('Error initializing app: $e');
    debugPrint('Stack trace: $stackTrace');
    // Still try to run the app even if some initialization failed
    runApp(
      MaterialApp(
        title: AppConstants.appName,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $e', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Check console for details'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RewriterApp extends StatelessWidget {
  const RewriterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
        ),
      ),
      home: const SettingsPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
