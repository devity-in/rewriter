import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'dart:io';
import '../../utils/constants.dart';

/// Manages system tray icon and menu
class TrayManager {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  final Function()? onSettingsClick;
  final Function()? onQuitClick;
  final Function()? onToggleClick;
  final Function(String)? onTextSelected;
  final Function()? onViewAllClick;

  bool _isEnabled = false;
  List<String> _rewrittenTexts = [];
  String? _originalText;
  String _status = 'idle'; // 'idle', 'processing', 'ready', 'error'

  TrayManager({
    this.onSettingsClick,
    this.onQuitClick,
    this.onToggleClick,
    this.onTextSelected,
    this.onViewAllClick,
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

      print('Icon saved to: ${iconFile.path}');
      print('Icon file exists: ${await iconFile.exists()}');
      print('Icon file size: ${await iconFile.length()} bytes');

      return iconFile.path;
    }
    return 'assets/icon.png';
  }

  /// Initialize system tray
  Future<void> initialize() async {
    try {
      final iconPath = await _getIconPath();
      print('Using icon path: $iconPath');

      print('Initializing system tray with icon: $iconPath');
      if (Platform.isMacOS) {
        print('Icon file exists: ${await File(iconPath).exists()}');
      }

      await _systemTray.initSystemTray(
        title: '', // Empty title to show only icon
        iconPath: iconPath,
      );

      print('System tray initialized successfully');
      print('System tray title: ${AppConstants.appName}');

      await _createMenu();
      _systemTray.setContextMenu(_menu);
      print('Context menu set successfully');

      // Verify the tray is set up
      print('Tray setup complete. Icon should be visible in menu bar.');

      // Handle tray icon click
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _systemTray.popUpContextMenu();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e, stackTrace) {
      print('Error in tray initialization: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Create context menu
  Future<void> _createMenu() async {
    final menuItems = <MenuItemBase>[];

    // Show status
    if (_status == 'processing') {
      menuItems.add(
        MenuItemLabel(label: '⏳ Processing...', onClicked: (menuItem) {}),
      );
      menuItems.add(MenuSeparator());
    } else if (_status == 'error') {
      menuItems.add(
        MenuItemLabel(label: '❌ Error occurred', onClicked: (menuItem) {}),
      );
      menuItems.add(MenuSeparator());
    }

    // Show rewritten text options if available
    if (_rewrittenTexts.isNotEmpty) {
      // Show original text snippet if available
      if (_originalText != null) {
        final originalSnippet = _originalText!.length > 60
            ? '${_originalText!.substring(0, 57)}...'
            : _originalText!;
        menuItems.add(
          MenuItemLabel(
            label: 'Original: "$originalSnippet"',
            onClicked: (menuItem) {},
          ),
        );
        menuItems.add(MenuSeparator());
      }

      menuItems.add(
        MenuItemLabel(
          label: 'Select rewritten text:',
          onClicked: (menuItem) {},
        ),
      );

      // Add up to 2 rewritten text options
      for (int i = 0; i < _rewrittenTexts.length && i < 2; i++) {
        final text = _rewrittenTexts[i];
        // Truncate long text for menu display (max 60 chars)
        final displayText = text.length > 60
            ? '${text.substring(0, 57)}...'
            : text;

        menuItems.add(
          MenuItemLabel(
            label: '${i + 1}. $displayText (Cmd+Shift+${i + 1})',
            onClicked: (menuItem) {
              onTextSelected?.call(text);
            },
          ),
        );
      }

      // Add "View All" option
      menuItems.add(
        MenuItemLabel(
          label: 'View All (Cmd+Shift+R)',
          onClicked: (menuItem) {
            onViewAllClick?.call();
          },
        ),
      );

      menuItems.add(MenuSeparator());
    }

    // Enable/Disable toggle
    menuItems.add(
      MenuItemLabel(
        label: _isEnabled ? 'Disable' : 'Enable',
        onClicked: (menuItem) {
          onToggleClick?.call();
        },
      ),
    );

    // Settings
    menuItems.add(
      MenuItemLabel(
        label: 'Settings',
        onClicked: (menuItem) {
          onSettingsClick?.call();
        },
      ),
    );

    menuItems.add(MenuSeparator());

    // Quit
    menuItems.add(
      MenuItemLabel(
        label: 'Quit',
        onClicked: (menuItem) {
          onQuitClick?.call();
        },
      ),
    );

    await _menu.buildFrom(menuItems);
  }

  /// Update menu based on enabled state
  Future<void> updateMenu(bool enabled) async {
    _isEnabled = enabled;
    await _createMenu();
    _systemTray.setContextMenu(_menu);
  }

  /// Update rewritten texts and refresh menu
  Future<void> updateRewrittenTexts(
    List<String> texts, {
    String? originalText,
  }) async {
    _rewrittenTexts = texts.take(2).toList(); // Keep only first 2
    if (originalText != null) {
      _originalText = originalText;
    }
    await _createMenu();
    _systemTray.setContextMenu(_menu);
  }

  /// Set tooltip
  Future<void> setTooltip(String tooltip) async {
    await _systemTray.setTitle(tooltip);
  }

  /// Update status and refresh menu
  Future<void> updateStatus(String status) async {
    _status = status;
    await _createMenu();
    _systemTray.setContextMenu(_menu);

    // Update tooltip based on status
    String tooltip;
    switch (status) {
      case 'processing':
        tooltip = 'Rewriter: Processing...';
        break;
      case 'ready':
        tooltip = 'Rewriter: ${_rewrittenTexts.length} version(s) ready';
        break;
      case 'error':
        tooltip = 'Rewriter: Error occurred';
        break;
      default:
        tooltip = _isEnabled ? 'Rewriter: Ready' : 'Rewriter: Disabled';
    }
    await setTooltip(tooltip);
  }
}
