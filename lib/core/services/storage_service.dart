import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';

/// Service for managing secure and persistent storage
class StorageService {
  // Configure secure storage - use default options for development
  // For macOS without signing, flutter_secure_storage will use UserDefaults as fallback
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(),
    mOptions: MacOsOptions(),
    lOptions: LinuxOptions(),
  );
  static const String _apiKeyKey = 'api_key';
  static const String _enabledKey = 'enabled';
  static const String _debounceMsKey = 'debounce_ms';
  static const String _minSentenceLengthKey = 'min_sentence_length';
  static const String _maxSentenceLengthKey = 'max_sentence_length';
  static const String _rewriteStyleKey = 'rewrite_style';
  static const String _modelTypeKey = 'model_type';
  static const String _modelUrlKey = 'model_url';
  static const String _kaggleUsernameKey = 'kaggle_username';
  static const String _kaggleKeyKey = 'kaggle_key';

  /// Save API key securely
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();

    // Always save to both secure storage and SharedPreferences as backup
    try {
      await _secureStorage.write(key: _apiKeyKey, value: apiKey);
      debugPrint('StorageService: API key saved to secure storage');

      // Verify it was saved by reading it back
      final saved = await _secureStorage.read(key: _apiKeyKey);
      if (saved != apiKey) {
        debugPrint(
          'Warning: Secure storage write verification failed, using SharedPreferences fallback',
        );
        await prefs.setString('${_apiKeyKey}_fallback', apiKey);
      } else {
        debugPrint('StorageService: API key verified in secure storage');
        // Also save to fallback for redundancy
        await prefs.setString('${_apiKeyKey}_fallback', apiKey);
      }
    } catch (e) {
      // Fallback to SharedPreferences if secure storage fails
      debugPrint('Warning: Secure storage failed, using SharedPreferences: $e');
      await prefs.setString('${_apiKeyKey}_fallback', apiKey);
    }
  }

  /// Get API key securely
  Future<String?> getApiKey() async {
    // Try secure storage first
    try {
      final apiKey = await _secureStorage.read(key: _apiKeyKey);
      if (apiKey != null && apiKey.isNotEmpty) {
        debugPrint('StorageService: API key loaded from secure storage');
        return apiKey;
      }
    } catch (e) {
      debugPrint('Warning: Secure storage read failed: $e');
    }

    // Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final fallbackKey = prefs.getString('${_apiKeyKey}_fallback');
      if (fallbackKey != null && fallbackKey.isNotEmpty) {
        debugPrint(
          'StorageService: API key loaded from SharedPreferences fallback',
        );
        // If we got it from fallback, try to restore it to secure storage
        try {
          await _secureStorage.write(key: _apiKeyKey, value: fallbackKey);
          debugPrint('StorageService: API key restored to secure storage');
        } catch (e) {
          debugPrint(
            'Warning: Could not restore API key to secure storage: $e',
          );
        }
        return fallbackKey;
      }
    } catch (e) {
      debugPrint('Warning: SharedPreferences read failed: $e');
    }

    debugPrint('StorageService: No API key found');
    return null;
  }

  /// Delete API key
  Future<void> deleteApiKey() async {
    try {
      await _secureStorage.delete(key: _apiKeyKey);
    } catch (e) {
      debugPrint('Warning: Secure storage delete failed: $e');
    }
    // Also delete fallback
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_apiKeyKey}_fallback');
  }

  /// Save app configuration
  Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, config.enabled);
    await prefs.setInt(_debounceMsKey, config.debounceMs);
    await prefs.setInt(_minSentenceLengthKey, config.minSentenceLength);
    await prefs.setInt(_maxSentenceLengthKey, config.maxSentenceLength);
    await prefs.setString(_rewriteStyleKey, config.rewriteStyle);
    await prefs.setString(_modelTypeKey, config.modelType);
    if (config.modelUrl != null) {
      await prefs.setString(_modelUrlKey, config.modelUrl!);
    } else {
      await prefs.remove(_modelUrlKey);
    }
    if (config.kaggleUsername != null) {
      await prefs.setString(_kaggleUsernameKey, config.kaggleUsername!);
    } else {
      await prefs.remove(_kaggleUsernameKey);
    }
    if (config.kaggleKey != null) {
      // Store Kaggle key securely
      await _secureStorage.write(key: _kaggleKeyKey, value: config.kaggleKey!);
    } else {
      await _secureStorage.delete(key: _kaggleKeyKey);
    }

    // Always save API key if provided, even if empty (to clear it)
    // Only save API key for Gemini model
    if (config.modelType == 'gemini') {
      if (config.apiKey != null) {
        await saveApiKey(config.apiKey!);
      } else {
        // If apiKey is explicitly null, delete it
        await deleteApiKey();
      }
    }
  }

  /// Load app configuration
  Future<AppConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final modelType =
        prefs.getString(_modelTypeKey) ?? 'gemini'; // Default to Gemini API

    // Only load API key for Gemini model
    final apiKey = modelType == 'gemini' ? await getApiKey() : null;

    final config = AppConfig(
      enabled: prefs.getBool(_enabledKey) ?? true,
      apiKey: apiKey,
      debounceMs: prefs.getInt(_debounceMsKey) ?? 1000,
      minSentenceLength: prefs.getInt(_minSentenceLengthKey) ?? 10,
      maxSentenceLength: prefs.getInt(_maxSentenceLengthKey) ?? 500,
      rewriteStyle: prefs.getString(_rewriteStyleKey) ?? 'professional',
      modelType: modelType,
      modelUrl: prefs.getString(_modelUrlKey),
      kaggleUsername: prefs.getString(_kaggleUsernameKey),
      kaggleKey: await _secureStorage.read(key: _kaggleKeyKey),
    );

    debugPrint(
      'StorageService: Config loaded - enabled: ${config.enabled}, modelType: ${config.modelType}, hasApiKey: ${config.isValid}',
    );

    return config;
  }
}
