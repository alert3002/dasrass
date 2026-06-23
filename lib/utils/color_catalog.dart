import '../services/dastrass_api.dart';
import 'board_filter_config.dart';

const _defaultColorCodes = [
  'white',
  'beige',
  'silver',
  'golden',
  'yellow',
  'orange',
  'red',
  'green',
  'light_blue',
  'blue',
  'purple',
  'brown',
  'wet_asphalt',
  'black',
  'other',
];

/// Подписи цветов по умолчанию (если API/админка ещё не загрузились).
List<String> defaultColorOptionLabels() {
  return _defaultColorCodes
      .map((code) => colorLabels[code])
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toList();
}

List<Map<String, String>> defaultColorCatalog() {
  return _defaultColorCodes
      .map((code) => {
            'code': code,
            'label': colorLabels[code] ?? code,
          })
      .where((e) => (e['label'] ?? '').isNotEmpty)
      .toList();
}

/// Каталог цветов из API — мисли [frontend/src/utils/colorCatalog.js].
class ColorCatalog {
  ColorCatalog._();
  static final instance = ColorCatalog._();

  List<Map<String, String>> _catalog = [];
  Future<void>? _loadPromise;

  List<Map<String, String>> get items =>
      List.unmodifiable(_catalog.isNotEmpty ? _catalog : defaultColorCatalog());

  List<String> get optionLabels {
    final source = _catalog.isNotEmpty ? _catalog : defaultColorCatalog();
    return source.map((e) => e['label'] ?? '').where((s) => s.isNotEmpty).toList();
  }

  String labelFor(String? code) {
    final c = (code ?? '').trim();
    if (c.isEmpty) return '';
    for (final row in items) {
      if (row['code'] == c) return row['label'] ?? c;
    }
    return colorLabels[c] ?? c;
  }

  String? codeForLabel(String? label) {
    final value = (label ?? '').trim();
    if (value.isEmpty) return null;
    for (final row in items) {
      if (row['label'] == value) return row['code'];
    }
    for (final e in colorLabels.entries) {
      if (e.value == value) return e.key;
    }
    return null;
  }

  Future<void> ensureLoaded({bool force = false}) async {
    if (!force && _catalog.isNotEmpty) return;
    if (_loadPromise != null) return _loadPromise!;
    _loadPromise = _load();
    try {
      await _loadPromise;
    } finally {
      _loadPromise = null;
    }
  }

  Future<void> _load() async {
    try {
      final rows = await DastrassApi.instance.colors();
      final parsed = rows
          .map((e) => {
                'code': '${e['code'] ?? ''}',
                'label': '${e['label'] ?? ''}',
              })
          .where((e) => e['code']!.isNotEmpty && (e['label'] ?? '').isNotEmpty)
          .toList();
      _catalog = parsed.isNotEmpty ? parsed : defaultColorCatalog();
      mergeColorLabels(_catalog);
    } catch (_) {
      _catalog = defaultColorCatalog();
      mergeColorLabels(_catalog);
    }
  }
}
