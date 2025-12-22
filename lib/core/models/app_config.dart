/// Application configuration model
class AppConfig {
  final bool enabled;
  final String? apiKey;
  final int debounceMs;
  final int minSentenceLength;
  final int maxSentenceLength;
  final String rewriteStyle;
  final String modelType; // 'gemini' or 'local'
  final String? modelUrl; // Optional URL to download model from at runtime
  final String? kaggleUsername; // Kaggle username for downloading models
  final String? kaggleKey; // Kaggle API key for downloading models

  AppConfig({
    this.enabled = true,
    this.apiKey,
    this.debounceMs = 1000,
    this.minSentenceLength = 10,
    this.maxSentenceLength = 500,
    this.rewriteStyle = 'professional',
    this.modelType = 'gemini', // Default to Gemini API
    this.modelUrl,
    this.kaggleUsername,
    this.kaggleKey,
  });

  AppConfig copyWith({
    bool? enabled,
    String? apiKey,
    int? debounceMs,
    int? minSentenceLength,
    int? maxSentenceLength,
    String? rewriteStyle,
    String? modelType,
    String? modelUrl,
    String? kaggleUsername,
    String? kaggleKey,
  }) {
    return AppConfig(
      enabled: enabled ?? this.enabled,
      apiKey: apiKey ?? this.apiKey,
      debounceMs: debounceMs ?? this.debounceMs,
      minSentenceLength: minSentenceLength ?? this.minSentenceLength,
      maxSentenceLength: maxSentenceLength ?? this.maxSentenceLength,
      rewriteStyle: rewriteStyle ?? this.rewriteStyle,
      modelType: modelType ?? this.modelType,
      modelUrl: modelUrl ?? this.modelUrl,
      kaggleUsername: kaggleUsername ?? this.kaggleUsername,
      kaggleKey: kaggleKey ?? this.kaggleKey,
    );
  }

  bool get isValid {
    if (modelType == 'local') {
      // Local AI doesn't need API key, just needs model file
      return true;
    }
    // Gemini needs API key
    return apiKey != null && apiKey!.isNotEmpty;
  }
}
