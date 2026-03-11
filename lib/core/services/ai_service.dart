import '../models/rewrite_result.dart';

/// Abstract interface for AI services that can rewrite text
abstract class AIService {
  /// Rewrite text using the AI service.
  /// [style] is one of the built-in styles or a custom style id.
  /// [customPrompt] is provided when a user-defined custom style is active.
  Future<RewriteResult> rewriteText(
    String text, {
    String style = 'professional',
    String? customPrompt,
  });

  /// Test connection to the AI service
  Future<bool> testConnection();
}
