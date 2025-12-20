/// Application configuration model
class AppConfig {
  final bool enabled;
  final String? apiKey;
  final int debounceMs;
  final int minSentenceLength;
  final int maxSentenceLength;
  final String rewriteStyle;
  final String modelType; // 'gemini' or 'phi3'

  AppConfig({
    this.enabled = true,
    this.apiKey,
    this.debounceMs = 1000,
    this.minSentenceLength = 10,
    this.maxSentenceLength = 500,
    this.rewriteStyle = 'professional',
    this.modelType = 'phi3', // Default to local AI
  });

  AppConfig copyWith({
    bool? enabled,
    String? apiKey,
    int? debounceMs,
    int? minSentenceLength,
    int? maxSentenceLength,
    String? rewriteStyle,
    String? modelType,
  }) {
    return AppConfig(
      enabled: enabled ?? this.enabled,
      apiKey: apiKey ?? this.apiKey,
      debounceMs: debounceMs ?? this.debounceMs,
      minSentenceLength: minSentenceLength ?? this.minSentenceLength,
      maxSentenceLength: maxSentenceLength ?? this.maxSentenceLength,
      rewriteStyle: rewriteStyle ?? this.rewriteStyle,
      modelType: modelType ?? this.modelType,
    );
  }

  bool get isValid {
    if (modelType == 'phi3') {
      // Phi3 doesn't need API key, just needs model file
      return true;
    }
    // Gemini needs API key
    return apiKey != null && apiKey!.isNotEmpty;
  }
}
