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
  final String themeMode; // 'system', 'light', or 'dark'
  final List<CustomStyle> customStyles;

  AppConfig({
    this.enabled = true,
    this.apiKey,
    this.debounceMs = 1000,
    this.minSentenceLength = 10,
    this.maxSentenceLength = 500,
    this.rewriteStyle = 'professional',
    this.modelType = 'nobodywho',
    this.modelUrl,
    this.ollamaBaseUrl,
    this.ollamaModel,
    this.themeMode = 'system',
    this.customStyles = const [],
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
    String? themeMode,
    List<CustomStyle>? customStyles,
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
      themeMode: themeMode ?? this.themeMode,
      customStyles: customStyles ?? this.customStyles,
    );
  }

  bool get isValid {
    if (modelType == 'local') {
      return true;
    }
    if (modelType == 'nobodywho') {
      return true;
    }
    if (modelType == 'ollama') {
      return (ollamaModel?.trim() ?? '').isNotEmpty;
    }
    return apiKey != null && apiKey!.isNotEmpty;
  }
}

/// A user-defined custom writing style with a custom prompt template
class CustomStyle {
  final String id;
  final String name;
  final String prompt;

  CustomStyle({required this.id, required this.name, required this.prompt});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'prompt': prompt};

  factory CustomStyle.fromJson(Map<String, dynamic> json) => CustomStyle(
    id: json['id'] as String,
    name: json['name'] as String,
    prompt: json['prompt'] as String,
  );
}
