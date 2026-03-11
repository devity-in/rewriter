import 'package:flutter/material.dart';
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

  ThemeMode get themeMode {
    switch (_config?.themeMode ?? 'system') {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  bool get hasApiKey {
    if (_config == null) return false;
    if (_config!.modelType == 'local') {
      final localAIService = _rewriterService.localAIService;
      if (localAIService != null) {
        return localAIService.isInitialized;
      }
      return _config!.modelUrl != null && _config!.modelUrl!.isNotEmpty;
    }
    if (_config!.modelType == 'nobodywho') {
      final nwService = _rewriterService.nobodyWhoService;
      if (nwService != null) {
        return nwService.isInitialized;
      }
      return _config!.isValid;
    }
    if (_config!.modelType == 'ollama') {
      return _config!.isValid;
    }
    return _config?.isValid ?? false;
  }

  bool get isLocalAIInitializing {
    if (_config?.modelType == 'local') {
      return _rewriterService.localAIService?.isInitializing ?? false;
    }
    if (_config?.modelType == 'nobodywho') {
      return _rewriterService.nobodyWhoService?.isInitializing ?? false;
    }
    return false;
  }

  RewriterService get rewriterService => _rewriterService;

  Future<void> _initialize() async {
    _config = await _storageService.loadConfig();
    _isInitialized = true;
    notifyListeners();

    // Refresh the UI whenever the AI service reports a status change
    // (e.g. NobodyWho finishes initializing). We chain with any
    // existing callback so the tray manager keeps working.
    final existingCallback = _rewriterService.onStatusChangedCallback;
    _rewriterService.onStatusChanged = (String status) {
      existingCallback?.call(status);
      notifyListeners();
    };

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
