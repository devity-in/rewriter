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

  /// Save API key securely
  Future<void> saveApiKey(String apiKey) async {
    try {
      await _secureStorage.write(key: _apiKeyKey, value: apiKey);
    } catch (e) {
      // Fallback to SharedPreferences if secure storage fails
      print('Warning: Secure storage failed, using SharedPreferences: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_apiKeyKey}_fallback', apiKey);
    }
  }

  /// Get API key securely
  Future<String?> getApiKey() async {
    try {
      return await _secureStorage.read(key: _apiKeyKey);
    } catch (e) {
      // Fallback to SharedPreferences if secure storage fails
      print('Warning: Secure storage read failed, trying SharedPreferences: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${_apiKeyKey}_fallback');
    }
  }

  /// Delete API key
  Future<void> deleteApiKey() async {
    try {
      await _secureStorage.delete(key: _apiKeyKey);
    } catch (e) {
      print('Warning: Secure storage delete failed: $e');
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
    
    if (config.apiKey != null) {
      await saveApiKey(config.apiKey!);
    }
  }

  /// Load app configuration
  Future<AppConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = await getApiKey();
    
    return AppConfig(
      enabled: prefs.getBool(_enabledKey) ?? true,
      apiKey: apiKey,
      debounceMs: prefs.getInt(_debounceMsKey) ?? 1000,
      minSentenceLength: prefs.getInt(_minSentenceLengthKey) ?? 10,
      maxSentenceLength: prefs.getInt(_maxSentenceLengthKey) ?? 500,
      rewriteStyle: prefs.getString(_rewriteStyleKey) ?? 'professional',
    );
  }
}
