import '../models/rewrite_result.dart';

/// Abstract interface for AI services that can rewrite text
abstract class AIService {
  /// Rewrite text using the AI service
  Future<RewriteResult> rewriteText(
    String text, {
    String style = 'professional',
  });

  /// Test connection to the AI service
  Future<bool> testConnection();
}
