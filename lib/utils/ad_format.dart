import 'package:intl/intl.dart';

/// Медиа с API часто `http://api.dasrass.com/...` — на Android нужен HTTPS.
String normalizeMediaUrl(String? raw) {
  var url = (raw ?? '').trim();
  if (url.isEmpty) return '';

  if (url.startsWith('http://api.dasrass.com')) {
    return 'https://${url.substring('http://'.length)}';
  }
  if (url.startsWith('http://api.dastrass.com')) {
    return url
        .replaceFirst('http://', 'https://')
        .replaceFirst('api.dastrass.com', 'api.dasrass.com');
  }

  try {
    final u = Uri.parse(url);
    final host = u.host.toLowerCase();
    if (host == '127.0.0.1' || host == 'localhost' || host == '10.0.2.2') {
      final path = u.path;
      if (path.startsWith('/media')) {
        return 'https://api.dasrass.com$path';
      }
    }
  } catch (_) {}

  if (url.startsWith('/media/')) {
    return 'https://api.dasrass.com$url';
  }

  return url;
}

/// Формат нарх дар рӯйхатҳо: 0 → «договорная», TJS → «c».
String formatAdListingPrice(dynamic price, String currency, {bool homeStyle = false}) {
  final n = num.tryParse('$price') ?? 0;
  if (n == 0) return 'договорная';
  final cur = currency.trim().toUpperCase();
  final formatted = NumberFormat.decimalPattern('ru_RU').format(n);
  if (cur.isEmpty || cur == 'TJS') return '$formatted c';
  return '$formatted ${currency.trim()}';
}

/// URL-и асосии сурат аз `image_url` ё массиви `images`.
String resolveAdImageUrl(Map<String, dynamic> ad) {
  final direct = normalizeMediaUrl('${ad['image_url'] ?? ''}');
  if (direct.isNotEmpty) return direct;

  final images = ad['images'];
  if (images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is String) {
      final s = normalizeMediaUrl(first);
      if (s.isNotEmpty) return s;
    }
    if (first is Map) {
      final m = Map<String, dynamic>.from(first);
      final u = normalizeMediaUrl('${m['image_url'] ?? m['url'] ?? m['src'] ?? ''}');
      if (u.isNotEmpty) return u;
    }
  }
  return '';
}
