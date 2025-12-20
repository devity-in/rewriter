import 'package:flutter/foundation.dart';
import '../../core/models/app_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/rewriter_service.dart';

/// Provider for managing app state
class AppProvider extends ChangeNotifier {
  final StorageService _storageService;
  final RewriterService _rewriterService;

  AppConfig? _config;
  bool _isInitialized = false;

  AppProvider({
    required StorageService storageService,
    required RewriterService rewriterService,
  }) : _storageService = storageService,
       _rewriterService = rewriterService {
    _initialize();
  }

  AppConfig? get config => _config;
  bool get isInitialized => _isInitialized;
  bool get isEnabled => _config?.enabled ?? false;
  bool get hasApiKey {
    if (_config == null) return false;
    // Phi3 doesn't need API key, Gemini does
    if (_config!.modelType == 'phi3') {
      return true; // Phi3 is valid if model file exists (checked at runtime)
    }
    return _config?.isValid ?? false;
  }

  RewriterService get rewriterService => _rewriterService;

  Future<void> _initialize() async {
    _config = await _storageService.loadConfig();
    _isInitialized = true;
    notifyListeners();

    if (_config?.enabled ?? false) {
      _rewriterService.start();
    }
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    _config = newConfig;
    await _storageService.saveConfig(newConfig);
    await _rewriterService.updateConfig(newConfig);
    notifyListeners();

    if (newConfig.enabled) {
      _rewriterService.start();
    } else {
      _rewriterService.stop();
    }
  }

  Future<void> toggleEnabled() async {
    if (_config != null) {
      await updateConfig(_config!.copyWith(enabled: !_config!.enabled));
    }
  }

  @override
  void dispose() {
    _rewriterService.dispose();
    super.dispose();
  }
}
