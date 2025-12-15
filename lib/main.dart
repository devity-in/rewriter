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
import 'ui/preview/preview_manager.dart';
import 'ui/preview/preview_window.dart';
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

    // Initialize preview manager
    final previewManager = PreviewManager(clipboardService: clipboardService);

    // Initialize app provider
    final appProvider = AppProvider(
      storageService: storageService,
      rewriterService: rewriterService,
    );

    // Initialize tray manager
    final trayManager = TrayManager(
      onSettingsClick: () async {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (e) {
          debugPrint('Error showing settings window: $e');
          // Try to show anyway - might work on retry
        }
      },
      onQuitClick: () {
        windowManager.close();
      },
      onToggleClick: () {
        appProvider.toggleEnabled();
      },
      onTextSelected: (String text) async {
        // Copy selected text to clipboard
        await clipboardService.setClipboardText(text);
        debugPrint('Copied to clipboard: $text');
      },
      onViewAllClick: () async {
        // Show preview window
        if (previewManager.isShowing) {
          await previewManager.hidePreview();
        } else if (previewManager.currentOriginalText != null &&
            previewManager.currentRewrittenTexts.isNotEmpty) {
          await previewManager.showPreview(
            originalText: previewManager.currentOriginalText!,
            rewrittenTexts: previewManager.currentRewrittenTexts,
          );
        }
      },
    );

    // Connect rewriter service to tray manager
    String? lastOriginalText;
    rewriterService.onRewrittenTextsChanged = (List<String> texts) {
      debugPrint('Rewritten texts available: ${texts.length}');
      trayManager.updateRewrittenTexts(texts, originalText: lastOriginalText);

      // Show preview window if texts are available
      if (texts.isNotEmpty && lastOriginalText != null) {
        previewManager.showPreview(
          originalText: lastOriginalText!,
          rewrittenTexts: texts,
        );
      }
    };

    // Track status changes
    rewriterService.onStatusChanged = (String status) {
      debugPrint('Status changed: $status');
      trayManager.updateStatus(status);
    };

    // Track original text for preview
    rewriterService.onOriginalTextChanged = (String originalText) {
      lastOriginalText = originalText;
    };

    // Setup hotkey callbacks
    hotkeyService.onShowPreview = () async {
      if (previewManager.isShowing) {
        await previewManager.hidePreview();
      } else if (previewManager.currentOriginalText != null &&
          previewManager.currentRewrittenTexts.isNotEmpty) {
        await previewManager.showPreview(
          originalText: previewManager.currentOriginalText!,
          rewrittenTexts: previewManager.currentRewrittenTexts,
        );
      }
    };

    hotkeyService.onSelectVersion1 = () async {
      if (previewManager.currentRewrittenTexts.isNotEmpty) {
        await clipboardService.setClipboardText(
          previewManager.currentRewrittenTexts[0],
        );
        await previewManager.hidePreview();
      }
    };

    hotkeyService.onSelectVersion2 = () async {
      if (previewManager.currentRewrittenTexts.length > 1) {
        await clipboardService.setClipboardText(
          previewManager.currentRewrittenTexts[1],
        );
        await previewManager.hidePreview();
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
        child: RewriterApp(
          previewManager: previewManager,
          clipboardService: clipboardService,
        ),
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
  final PreviewManager previewManager;
  final ClipboardService clipboardService;

  const RewriterApp({
    super.key,
    required this.previewManager,
    required this.clipboardService,
  });

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
      home: Consumer<AppProvider>(
        builder: (context, provider, child) {
          // If preview is showing, show preview window, otherwise settings
          if (previewManager.isShowing) {
            return PreviewWindow(
              originalText: previewManager.currentOriginalText ?? '',
              rewrittenTexts: previewManager.currentRewrittenTexts,
              clipboardService: clipboardService,
              onDismiss: () async {
                await previewManager.hidePreview();
              },
            );
          }

          return const SettingsPage();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
