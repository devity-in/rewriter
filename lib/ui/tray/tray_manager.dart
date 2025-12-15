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

  bool _isEnabled = false;
  String _status = 'idle'; // 'idle', 'processing', 'ready', 'error'

  TrayManager({
    this.onSettingsClick,
    this.onQuitClick,
    this.onToggleClick,
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
      
      // Ensure title stays empty (no app name)
      await _systemTray.setTitle('');

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

  /// Create context menu - simplified to show only status and settings
  Future<void> _createMenu() async {
    final menuItems = <MenuItemBase>[];

    // Show status
    String statusLabel;
    switch (_status) {
      case 'processing':
        statusLabel = '⏳ Processing...';
        break;
      case 'ready':
        statusLabel = '✅ Ready';
        break;
      case 'error':
        statusLabel = '❌ Error';
        break;
      default:
        statusLabel = _isEnabled ? '✓ Active' : '○ Inactive';
    }
    
    menuItems.add(
      MenuItemLabel(label: statusLabel, onClicked: (menuItem) {}),
    );
    menuItems.add(MenuSeparator());

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


  /// Update status and refresh menu
  Future<void> updateStatus(String status) async {
    _status = status;
    await _createMenu();
    _systemTray.setContextMenu(_menu);
    
    // Ensure title remains empty (no app name shown)
    await _systemTray.setTitle('');
  }
}
