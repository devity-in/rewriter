/// Model for a rewrite history item
class RewriteHistoryItem {
  final String originalText;
  final List<String> rewrittenTexts;
  final DateTime timestamp;
  final String style;

  RewriteHistoryItem({
    required this.originalText,
    required this.rewrittenTexts,
    required this.timestamp,
    required this.style,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'originalText': originalText,
      'rewrittenTexts': rewrittenTexts,
      'timestamp': timestamp.toIso8601String(),
      'style': style,
    };
  }

  /// Create from JSON
  factory RewriteHistoryItem.fromJson(Map<String, dynamic> json) {
    return RewriteHistoryItem(
      originalText: json['originalText'] as String,
      rewrittenTexts: List<String>.from(json['rewrittenTexts'] as List),
      timestamp: DateTime.parse(json['timestamp'] as String),
      style: json['style'] as String? ?? 'professional',
    );
  }

  /// Get display text for menu
  String get displayText {
    if (rewrittenTexts.isEmpty) return originalText;
    return rewrittenTexts.first;
  }
}






