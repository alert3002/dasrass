import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Базовый URL API (как во фронтенде: `.../api`).
///
/// **По умолчанию:** `https://api.dasrass.com/api` (онлайн, мисли `frontend/.env.production`).
///
/// Локальный Django только явно:
/// `flutter run --dart-define=API_BASE=http://127.0.0.1:8000/api`
///
/// **Android emulator + локальный API:** `localhost` / `127.0.0.1` → `10.0.2.2`.
class ApiConfig {
  ApiConfig._();

  static const String productionApiBase = 'https://api.dasrass.com/api';

  /// Пустая строка = [productionApiBase].
  static const String _baseFromEnvironment = String.fromEnvironment(
    'API_BASE',
    defaultValue: '',
  );

  static String _effectiveRawBase() {
    final s = _baseFromEnvironment.trim();
    if (s.isNotEmpty) return s;
    return productionApiBase;
  }

  /// Эффективный базовый URL (с учётом Android emulator → хост ПК).
  static String get base => _ensureApiPath(_resolveBaseForPlatform(_effectiveRawBase()));

  /// Если забыли суффикс `/api` (`http://10.0.2.2:8000`), дополняем до `.../api`.
  static String _ensureApiPath(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'/+$'), '');
    final u = Uri.tryParse(s);
    if (u == null || !u.hasAuthority) return s;
    final path = u.path;
    if (path.isEmpty || path == '/') {
      return '${u.origin}/api';
    }
    return s;
  }

  static String _resolveBaseForPlatform(String raw) {
    if (kIsWeb) return raw;
    if (defaultTargetPlatform != TargetPlatform.android) return raw;
    try {
      final u = Uri.parse(raw);
      final h = u.host.toLowerCase();
      if (h == 'localhost' || h == '127.0.0.1') {
        return u.replace(host: '10.0.2.2').toString();
      }
    } catch (_) {}
    return raw;
  }

  /// Ссылка на объявление в вебе (шер дар Reels). По умолчанию: https://dasrass.com
  static const String _webOriginFromEnvironment = String.fromEnvironment(
    'WEB_ORIGIN',
    defaultValue: '',
  );

  static String get publicSiteOrigin {
    final fromEnv = _webOriginFromEnvironment.trim();
    if (fromEnv.isNotEmpty) {
      return fromEnv.replaceAll(RegExp(r'/+$'), '');
    }
    final b = base.replaceAll(RegExp(r'/+$'), '');
    if (b.endsWith('/api')) return b.substring(0, b.length - 4);
    return 'https://dasrass.com';
  }
}
