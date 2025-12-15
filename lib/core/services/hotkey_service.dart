import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Service for managing global keyboard shortcuts
class HotkeyService {
  HotKey? _copyRewrittenHotkey;
  HotKey? _showSettingsHotkey;
  HotKey? _toggleEnabledHotkey;

  Function()? onCopyRewritten;
  Function()? onShowSettings;
  Function()? onToggleEnabled;

  /// Initialize hotkeys
  Future<void> initialize() async {
    if (!Platform.isMacOS) {
      debugPrint('HotkeyService: Only macOS is supported');
      return;
    }

    try {
      // Cmd+Shift+C - Copy rewritten text
      _copyRewrittenHotkey = HotKey(
        key: LogicalKeyboardKey.keyC,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        _copyRewrittenHotkey!,
        keyDownHandler: (hotKey) {
          debugPrint('Hotkey: Cmd+Shift+C pressed');
          onCopyRewritten?.call();
        },
      );

      // Cmd+Shift+S - Show settings
      _showSettingsHotkey = HotKey(
        key: LogicalKeyboardKey.keyS,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        _showSettingsHotkey!,
        keyDownHandler: (hotKey) {
          debugPrint('Hotkey: Cmd+Shift+S pressed');
          onShowSettings?.call();
        },
      );

      // Cmd+Shift+T - Toggle enabled
      _toggleEnabledHotkey = HotKey(
        key: LogicalKeyboardKey.keyT,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        _toggleEnabledHotkey!,
        keyDownHandler: (hotKey) {
          debugPrint('Hotkey: Cmd+Shift+T pressed');
          onToggleEnabled?.call();
        },
      );

      debugPrint('HotkeyService: All hotkeys registered successfully');
    } catch (e) {
      debugPrint('HotkeyService: Error registering hotkeys: $e');
    }
  }

  /// Unregister all hotkeys
  Future<void> dispose() async {
    try {
      if (_copyRewrittenHotkey != null) {
        await hotKeyManager.unregister(_copyRewrittenHotkey!);
      }
      if (_showSettingsHotkey != null) {
        await hotKeyManager.unregister(_showSettingsHotkey!);
      }
      if (_toggleEnabledHotkey != null) {
        await hotKeyManager.unregister(_toggleEnabledHotkey!);
      }
    } catch (e) {
      debugPrint('HotkeyService: Error unregistering hotkeys: $e');
    }
  }
}

