import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Service for managing global keyboard shortcuts
class HotkeyService {
  HotKey? _showPreviewHotkey;
  HotKey? _selectVersion1Hotkey;
  HotKey? _selectVersion2Hotkey;
  HotKey? _showSettingsHotkey;
  HotKey? _toggleEnabledHotkey;

  Function()? onShowPreview;
  Function()? onSelectVersion1;
  Function()? onSelectVersion2;
  Function()? onShowSettings;
  Function()? onToggleEnabled;

  /// Initialize hotkeys
  Future<void> initialize() async {
    if (!Platform.isMacOS) {
      debugPrint('HotkeyService: Only macOS is supported');
      return;
    }

    try {
      // Cmd+Shift+R - Show preview window
      _showPreviewHotkey = HotKey(
        key: LogicalKeyboardKey.keyR,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        _showPreviewHotkey!,
        keyDownHandler: (hotKey) {
          debugPrint('Hotkey: Cmd+Shift+R pressed');
          onShowPreview?.call();
        },
      );

      // Cmd+Shift+1 - Select version 1
      _selectVersion1Hotkey = HotKey(
        key: LogicalKeyboardKey.digit1,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        _selectVersion1Hotkey!,
        keyDownHandler: (hotKey) {
          debugPrint('Hotkey: Cmd+Shift+1 pressed');
          onSelectVersion1?.call();
        },
      );

      // Cmd+Shift+2 - Select version 2
      _selectVersion2Hotkey = HotKey(
        key: LogicalKeyboardKey.digit2,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        _selectVersion2Hotkey!,
        keyDownHandler: (hotKey) {
          debugPrint('Hotkey: Cmd+Shift+2 pressed');
          onSelectVersion2?.call();
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
      if (_showPreviewHotkey != null) {
        await hotKeyManager.unregister(_showPreviewHotkey!);
      }
      if (_selectVersion1Hotkey != null) {
        await hotKeyManager.unregister(_selectVersion1Hotkey!);
      }
      if (_selectVersion2Hotkey != null) {
        await hotKeyManager.unregister(_selectVersion2Hotkey!);
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

