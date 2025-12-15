/// Result of a rewrite operation
class RewriteResult {
  final String originalText;
  final String rewrittenText;
  final bool success;
  final String? error;

  RewriteResult({
    required this.originalText,
    required this.rewrittenText,
    required this.success,
    this.error,
  });

  factory RewriteResult.success({
    required String originalText,
    required String rewrittenText,
  }) {
    return RewriteResult(
      originalText: originalText,
      rewrittenText: rewrittenText,
      success: true,
    );
  }

  factory RewriteResult.failure({
    required String originalText,
    required String error,
  }) {
    return RewriteResult(
      originalText: originalText,
      rewrittenText: originalText,
      success: false,
      error: error,
    );
  }
}


