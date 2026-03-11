import 'package:flutter/services.dart';

class AppInfo {
  final String bundleId;
  final String name;

  const AppInfo({required this.bundleId, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppInfo && runtimeType == other.runtimeType && bundleId == other.bundleId;

  @override
  int get hashCode => bundleId.hashCode;

  @override
  String toString() => '$name ($bundleId)';
}

class PlatformService {
  static const _channel = MethodChannel('com.rewriter/platform');

  Future<AppInfo?> getFrontmostApp() async {
    try {
      final result = await _channel.invokeMethod<Map>('getFrontmostApp');
      if (result == null || result['bundleId'] == null || (result['bundleId'] as String).isEmpty) {
        return null;
      }
      return AppInfo(
        bundleId: result['bundleId'] as String,
        name: result['name'] as String? ?? result['bundleId'] as String,
      );
    } on PlatformException {
      return null;
    }
  }

  Future<List<AppInfo>> getRunningApps() async {
    try {
      final result = await _channel.invokeMethod<List>('getRunningApps');
      if (result == null) return [];
      return result
          .cast<Map>()
          .map((m) => AppInfo(
                bundleId: m['bundleId'] as String,
                name: m['name'] as String? ?? m['bundleId'] as String,
              ))
          .toList();
    } on PlatformException {
      return [];
    }
  }
}
