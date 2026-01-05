import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing onboarding state
class OnboardingService {
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _hasSeenWelcomeKey = 'has_seen_welcome';

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedOnboardingKey) ?? false;
  }

  /// Check if user has seen welcome screen
  Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenWelcomeKey) ?? false;
  }

  /// Mark onboarding as completed
  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedOnboardingKey, true);
  }

  /// Mark welcome as seen
  Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenWelcomeKey, true);
  }

  /// Reset onboarding (for testing)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasCompletedOnboardingKey);
    await prefs.remove(_hasSeenWelcomeKey);
  }
}
