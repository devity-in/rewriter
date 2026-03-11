import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'dart:io';

/// Manages system tray icon and menu
class TrayManager {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  final Function()? onSettingsClick;
  final Function()? onQuitClick;
  final Function()? onToggleClick;
  final Function(String style)? onStyleChanged;

  bool _isEnabled = false;
  String _status = 'idle';
  String _modelType = 'nobodywho';
  String _rewriteStyle = 'professional';
  String _appFilterMode = 'all';

  TrayManager({
    this.onSettingsClick,
    this.onQuitClick,
    this.onToggleClick,
    this.onStyleChanged,
  });

  /// Get the icon path for the system tray
  Future<String> _getIconPath() async {
    if (Platform.isMacOS) {
      // On macOS, system_tray requires an actual file path, not a Flutter asset path
      // So we need to copy the asset to a real file location
      final ByteData data = await rootBundle.load('assets/icon.png');

      // Use home directory for icon storage (more reliable than temp)
      final String homeDir = Platform.environment['HOME'] ?? '/tmp';
      final String iconDir = '$homeDir/.rewriter';
      final Directory dir = Directory(iconDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final File iconFile = File('$iconDir/tray_icon.png');
      await iconFile.writeAsBytes(data.buffer.asUint8List());

      // Verify the file was created successfully
      if (!await iconFile.exists()) {
        throw Exception('Failed to create icon file at ${iconFile.path}');
      }

      debugPrint('Icon saved to: ${iconFile.path}');
      debugPrint('Icon file exists: ${await iconFile.exists()}');
      debugPrint('Icon file size: ${await iconFile.length()} bytes');

      return iconFile.path;
    }
    return 'assets/icon.png';
  }

  /// Initialize system tray
  Future<void> initialize() async {
    try {
      final iconPath = await _getIconPath();
      debugPrint('Using icon path: $iconPath');

      debugPrint('Initializing system tray with icon: $iconPath');
      if (Platform.isMacOS) {
        debugPrint('Icon file exists: ${await File(iconPath).exists()}');
      }

      await _systemTray.initSystemTray(
        title: '', // Empty title to show only icon
        iconPath: iconPath,
      );

      debugPrint('System tray initialized successfully');

      // Ensure title stays empty (no app name)
      await _systemTray.setTitle('');

      await _createMenu();
      _systemTray.setContextMenu(_menu);
      debugPrint('Context menu set successfully');

      // Verify the tray is set up
      debugPrint('Tray setup complete. Icon should be visible in menu bar.');

      // Handle tray icon click
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _systemTray.popUpContextMenu();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Error in tray initialization: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'processing':
        return '⏳ Rewriting...';
      case 'ready':
        return '✅ Ready';
      case 'error':
        return '❌ Error';
      default:
        return _isEnabled ? '✅ Active' : '⏸ Paused';
    }
  }

  String get _modelLabel {
    switch (_modelType) {
      case 'gemini':
        return 'Gemini';
      case 'ollama':
        return 'Ollama';
      case 'local':
        return 'Local AI';
      case 'nobodywho':
        return 'On-device';
      default:
        return _modelType;
    }
  }

  String _styleLabel(String style) {
    switch (style) {
      case 'professional':
        return 'Professional';
      case 'casual':
        return 'Casual';
      case 'concise':
        return 'Concise';
      case 'academic':
        return 'Academic';
      default:
        return style;
    }
  }

  String get _filterLabel {
    switch (_appFilterMode) {
      case 'allowlist':
        return 'Allowlist';
      case 'blocklist':
        return 'Blocklist';
      default:
        return 'All Apps';
    }
  }

  Future<void> _createMenu() async {
    final items = <MenuItemBase>[];

    // ── Status line ──
    items.add(MenuItemLabel(label: 'Rewriter — $_statusLabel', onClicked: (_) {}));
    items.add(MenuSeparator());

    // ── Toggle on/off ──
    items.add(MenuItemLabel(
      label: _isEnabled ? '⏸  Pause Rewriting' : '▶  Resume Rewriting',
      onClicked: (_) => onToggleClick?.call(),
    ));
    items.add(MenuSeparator());

    // ── Quick style picker ──
    const styles = ['professional', 'casual', 'concise', 'academic'];
    final styleSubmenu = <MenuItemBase>[];
    for (final s in styles) {
      final isCurrent = s == _rewriteStyle;
      styleSubmenu.add(MenuItemLabel(
        label: '${isCurrent ? "● " : "   "}${_styleLabel(s)}',
        onClicked: (_) {
          if (!isCurrent) onStyleChanged?.call(s);
        },
      ));
    }
    final styleMenu = SubMenu(label: 'Style: ${_styleLabel(_rewriteStyle)}', children: styleSubmenu);
    items.add(styleMenu);

    // ── Info line: model + filter ──
    items.add(MenuItemLabel(label: 'Model: $_modelLabel', onClicked: (_) {}));
    items.add(MenuItemLabel(label: 'Filter: $_filterLabel', onClicked: (_) {}));
    items.add(MenuSeparator());

    // ── Open window / Settings ──
    items.add(MenuItemLabel(
      label: 'Open Rewriter',
      onClicked: (_) => onSettingsClick?.call(),
    ));
    items.add(MenuSeparator());

    // ── Quit ──
    items.add(MenuItemLabel(label: 'Quit', onClicked: (_) => onQuitClick?.call()));

    await _menu.buildFrom(items);
  }

  Future<void> _refresh() async {
    await _createMenu();
    _systemTray.setContextMenu(_menu);
    await _systemTray.setTitle('');
  }

  /// Update enabled state and refresh menu
  Future<void> updateMenu(bool enabled) async {
    _isEnabled = enabled;
    await _refresh();
  }

  /// Update status and refresh menu
  Future<void> updateStatus(String status) async {
    _status = status;
    await _refresh();
  }

  /// Update config-driven fields and refresh menu
  Future<void> updateConfig({
    required bool enabled,
    required String modelType,
    required String rewriteStyle,
    required String appFilterMode,
  }) async {
    _isEnabled = enabled;
    _modelType = modelType;
    _rewriteStyle = rewriteStyle;
    _appFilterMode = appFilterMode;
    await _refresh();
  }
}
