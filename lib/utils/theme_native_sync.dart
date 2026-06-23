import 'package:flutter/services.dart';

/// Синхронизирует тему в Android SharedPreferences (splash до старта Flutter).
class ThemeNativeSync {
  ThemeNativeSync._();

  static const _channel = MethodChannel('com.dastrass/theme');

  static Future<void> save(String prefName) async {
    try {
      await _channel.invokeMethod<void>('setThemePref', prefName);
    } catch (_) {
      // Web / iOS — noop.
    }
  }
}
