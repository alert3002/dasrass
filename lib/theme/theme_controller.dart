import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/theme_native_sync.dart';

/// Предпочтение темы — мисли [frontend/src/utils/themePreference.js].
enum ThemePref { system, dark, light, auto }

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  static const _prefKey = 'dastrassThemePref';

  ThemePref _pref = ThemePref.system;
  Timer? _autoTimer;

  ThemePref get preference => _pref;

  /// Для [MaterialApp.themeMode]: system / light / dark (auto ҳисоб мешавад).
  ThemeMode get mode {
    switch (_pref) {
      case ThemePref.system:
        return ThemeMode.system;
      case ThemePref.dark:
        return ThemeMode.dark;
      case ThemePref.light:
        return ThemeMode.light;
      case ThemePref.auto:
        final phase = resolveAutoPhase();
        return phase == 'light' ? ThemeMode.light : ThemeMode.dark;
    }
  }

  bool get isLight => mode == ThemeMode.light;

  bool get isDark => mode == ThemeMode.dark;

  /// Час дар Душанбе: 08–19 светлая, 19–20 приглушённая, 20–08 тёмная.
  static String resolveAutoPhase([DateTime? now]) {
    final utc = (now ?? DateTime.now()).toUtc();
    final dushanbe = utc.add(const Duration(hours: 5));
    final h = dushanbe.hour;
    if (h >= 8 && h < 19) return 'light';
    if (h >= 19 && h < 20) return 'dimmed';
    return 'dark';
  }

  String resolveApplied() {
    switch (_pref) {
      case ThemePref.dark:
        return 'dark';
      case ThemePref.light:
        return 'light';
      case ThemePref.system:
        return 'system';
      case ThemePref.auto:
        return resolveAutoPhase();
    }
  }

  String get labelRu => appliedThemeLabelRu(resolveApplied());

  static String appliedThemeLabelRu(String applied) {
    switch (applied) {
      case 'dark':
        return 'тёмная';
      case 'light':
        return 'светлая';
      case 'dimmed':
        return 'приглушённая';
      case 'system':
        return 'системная';
      default:
        return applied;
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_prefKey);
    _pref = _parsePref(v) ?? ThemePref.system;
    await ThemeNativeSync.save(_pref.name);
    _restartAutoTimer();
    notifyListeners();
  }

  ThemePref? _parsePref(String? v) {
    switch (v) {
      case 'system':
        return ThemePref.system;
      case 'dark':
        return ThemePref.dark;
      case 'light':
        return ThemePref.light;
      case 'auto':
        return ThemePref.auto;
      default:
        return null;
    }
  }

  Future<void> setPreference(ThemePref pref) => _set(pref);

  Future<void> setLight() => _set(ThemePref.light);

  Future<void> setDark() => _set(ThemePref.dark);

  Future<void> setSystem() => _set(ThemePref.system);

  Future<void> setAuto() => _set(ThemePref.auto);

  void refreshAfterFontsLoaded() => notifyListeners();

  Future<void> _set(ThemePref pref) async {
    _pref = pref;
    _restartAutoTimer();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKey, pref.name);
    await ThemeNativeSync.save(pref.name);
  }

  void _restartAutoTimer() {
    _autoTimer?.cancel();
    if (_pref != ThemePref.auto) return;
    _autoTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      notifyListeners();
    });
  }
}
