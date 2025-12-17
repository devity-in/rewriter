// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:rewriter/main.dart';
import 'package:rewriter/core/services/storage_service.dart';
import 'package:rewriter/core/services/clipboard_service.dart';
import 'package:rewriter/core/services/language_detector.dart';
import 'package:rewriter/core/services/rewriter_service.dart';
import 'package:rewriter/core/services/onboarding_service.dart';
import 'package:rewriter/ui/providers/app_provider.dart';

void main() {
  testWidgets('RewriterApp builds successfully', (WidgetTester tester) async {
    // Initialize services for testing
    final storageService = StorageService();
    final clipboardService = ClipboardService();
    final languageDetector = LanguageDetector();
    final rewriterService = RewriterService(
      clipboardService: clipboardService,
      languageDetector: languageDetector,
      storageService: storageService,
    );
    final onboardingService = OnboardingService();

    // Mark onboarding as complete to skip welcome dialog in tests
    await onboardingService.markWelcomeSeen();
    await onboardingService.markOnboardingComplete();

    final appProvider = AppProvider(
      storageService: storageService,
      rewriterService: rewriterService,
    );

    // Build our app and trigger a frame.
    // Note: windowManager is a singleton, accessed via windowManager global
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appProvider,
        child: RewriterApp(
          onboardingService: onboardingService,
          appProvider: appProvider,
          windowManager: windowManager, // Global singleton instance
        ),
      ),
    );

    // Wait for app to initialize and onboarding check to complete
    await tester.pumpAndSettle();

    // Verify that the app builds and shows Settings page
    expect(find.text('Settings'), findsOneWidget);
  });
}
