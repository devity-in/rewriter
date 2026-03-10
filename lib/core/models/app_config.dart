/// Application configuration model
class AppConfig {
  final bool enabled;
  final String? apiKey;
  final int debounceMs;
  final int minSentenceLength;
  final int maxSentenceLength;
  final String rewriteStyle;
  final String modelType; // 'gemini', 'local', 'ollama', or 'nobodywho'
  final String? modelUrl; // URL to download model from at runtime (required for local AI)
  final String? ollamaBaseUrl; // Ollama server URL (e.g. http://localhost:11434)
  final String? ollamaModel; // Ollama model name (e.g. llama2, mistral)

  AppConfig({
    this.enabled = true,
    this.apiKey,
    this.debounceMs = 1000,
    this.minSentenceLength = 10,
    this.maxSentenceLength = 500,
    this.rewriteStyle = 'professional',
    this.modelType = 'gemini',
    this.modelUrl,
    this.ollamaBaseUrl,
    this.ollamaModel,
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
    String? ollamaBaseUrl,
    String? ollamaModel,
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
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaModel: ollamaModel ?? this.ollamaModel,
    );
  }

  bool get isValid {
    if (modelType == 'local') {
      return true;
    }
    if (modelType == 'nobodywho') {
      // Bundled model — always valid once selected
      return true;
    }
    if (modelType == 'ollama') {
      return (ollamaModel?.trim() ?? '').isNotEmpty;
    }
    return apiKey != null && apiKey!.isNotEmpty;
  }
}
