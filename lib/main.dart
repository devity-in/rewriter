import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'core/services/storage_service.dart';
import 'core/services/clipboard_service.dart';
import 'core/services/language_detector.dart';
import 'core/services/rewriter_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/hotkey_service.dart';
import 'core/services/rate_limit_service.dart';
import 'core/services/onboarding_service.dart';
import 'ui/providers/app_provider.dart';
import 'ui/tray/tray_manager.dart';
import 'ui/settings/settings_page.dart';
import 'ui/onboarding/welcome_dialog.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize window manager for desktop
    await windowManager.ensureInitialized();

    // Set window options for system tray app
    const windowOptions = WindowOptions(
      skipTaskbar: true,
      backgroundColor:
          Colors.white, // Use white background instead of transparent
      size: Size(800, 600),
      minimumSize: Size(600, 400),
    );

    await windowManager.waitUntilReadyToShow(windowOptions);

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Initialize onboarding service
    final onboardingService = OnboardingService();

    // Check if onboarding is needed BEFORE hiding window
    final hasCompletedOnboarding = await onboardingService
        .hasCompletedOnboarding();

    // Only hide window if onboarding is already complete
    // Otherwise, show window for onboarding
    if (hasCompletedOnboarding) {
      try {
        await windowManager.hide();
      } catch (e) {
        debugPrint('Note: Window hide called early: $e');
      }
    } else {
      // Show window for onboarding
      try {
        await windowManager.setMinimumSize(const Size(600, 400));
        await windowManager.setSize(const Size(800, 600));
        await windowManager.center();
        await windowManager.show();
        await windowManager.focus();
      } catch (e) {
        debugPrint('Error showing window for onboarding: $e');
      }
    }

    // Initialize hotkey service
    final hotkeyService = HotkeyService();

    // Initialize services
    final storageService = StorageService();
    final clipboardService = ClipboardService();
    final languageDetector = LanguageDetector();
    final rateLimitService = RateLimitService();
    final rewriterService = RewriterService(
      clipboardService: clipboardService,
      languageDetector: languageDetector,
      storageService: storageService,
      rateLimitService: rateLimitService,
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
          // Check if window is already visible
          final isVisible = await windowManager.isVisible();

          if (!isVisible) {
            // Ensure window has proper size and is visible
            await windowManager.setMinimumSize(const Size(600, 400));
            await windowManager.setSize(const Size(800, 600));
            await windowManager.center();
            // Show window
            await windowManager.show();
            // Small delay to ensure Flutter has time to render
            await Future.delayed(const Duration(milliseconds: 100));
          }
          // Focus and bring to front
          await windowManager.focus();
        } catch (e) {
          debugPrint('Error showing settings window: $e');
        }
      },
      onQuitClick: () {
        exit(0);
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
        // Check if window is already visible
        final isVisible = await windowManager.isVisible();

        if (!isVisible) {
          // Ensure window has proper size and is visible
          await windowManager.setMinimumSize(const Size(600, 400));
          await windowManager.setSize(const Size(800, 600));
          await windowManager.center();
          // Show window
          await windowManager.show();
          // Small delay to ensure Flutter has time to render
          await Future.delayed(const Duration(milliseconds: 100));
        }
        // Focus and bring to front
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
        child: RewriterApp(
          onboardingService: onboardingService,
          appProvider: appProvider,
          windowManager: windowManager,
        ),
      ),
    );

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

class RewriterApp extends StatefulWidget {
  final OnboardingService onboardingService;
  final AppProvider appProvider;
  final WindowManager windowManager;

  const RewriterApp({
    super.key,
    required this.onboardingService,
    required this.appProvider,
    required this.windowManager,
  });

  @override
  State<RewriterApp> createState() => _RewriterAppState();
}

class _RewriterAppState extends State<RewriterApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboarding();
    });
  }

  Future<void> _checkAndShowOnboarding() async {
    // Check if onboarding has been completed
    final hasCompletedOnboarding = await widget.onboardingService
        .hasCompletedOnboarding();

    // Only show onboarding if it hasn't been completed yet
    if (!hasCompletedOnboarding) {
      // Ensure window is visible for onboarding
      try {
        await widget.windowManager.setMinimumSize(const Size(600, 400));
        await widget.windowManager.setSize(const Size(800, 600));
        await widget.windowManager.center();
        await widget.windowManager.show();
        await widget.windowManager.focus();
      } catch (e) {
        debugPrint('Error showing window for onboarding: $e');
      }

      // Wait for navigator to be ready
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      final navigator = _navigatorKey.currentState;
      if (navigator == null || !navigator.mounted) return;

      // Show welcome dialog
      final shouldShowSettings = await showDialog<bool>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (context) => WelcomeDialog(
          onboardingService: widget.onboardingService,
          onComplete: () {
            Navigator.of(context).pop(true);
          },
        ),
      );

      if (shouldShowSettings == true) {
        // User clicked "Get Started" - just mark welcome as seen
        // Settings page is already showing, so user can configure there
        await widget.onboardingService.markWelcomeSeen();
        // Don't mark onboarding complete yet - let user complete setup in settings
        // Window stays visible so user can configure settings
      } else {
        // User skipped, mark welcome as seen and hide window
        await widget.onboardingService.markWelcomeSeen();
        try {
          await widget.windowManager.hide();
        } catch (e) {
          debugPrint('Error hiding window after skip: $e');
        }
      }
    } else {
      // Onboarding already completed, ensure window is hidden
      try {
        await widget.windowManager.hide();
      } catch (e) {
        debugPrint('Error hiding window: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
    );
  }
}
