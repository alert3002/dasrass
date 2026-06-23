/// Легковой автомобиль — фильтры, кузов, характеристики.
class PassengerCarConfig {
  PassengerCarConfig._();

  /// Список кузовов (расми 1).
  static const List<String> bodyTypes = [
    'Седан',
    'Хэтчбек',
    'Универсал',
    'Внедорожник',
    'Кроссовер',
    'Пикап',
    'Минивэн',
    'Фургон',
    'Кабриолет',
    'Купе',
    'Лифтбэк',
  ];
}

bool isPassengerCarContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final cat = (categorySlug ?? '').trim().toLowerCase();
  if (cat != 'transport') return false;
  final slugs = <String>{
    if ((subcategorySlug ?? '').trim().isNotEmpty) subcategorySlug!.trim().toLowerCase(),
    ...subcategoryPathSlugs.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty),
  };
  return slugs.any((s) => s.contains('legkovoy') || s.contains('легков'));
}

String parseBodyTypeFromDescription(String? description) {
  for (final line in (description ?? '').split('\n').take(8)) {
    final m = RegExp(r'^\s*Кузов\s*:\s*(.+)\s*$', caseSensitive: false).firstMatch(line);
    if (m != null) return m.group(1)!.trim();
  }
  return '';
}

String stripBodyTypeFromDescription(String? description) {
  final lines = (description ?? '').split('\n');
  final kept = lines.where((line) => !RegExp(r'^\s*Кузов\s*:', caseSensitive: false).hasMatch(line));
  return kept.join('\n').trim();
}

String normalizePassengerBodyType(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return '';
  if (PassengerCarConfig.bodyTypes.contains(t)) return t;
  final lower = t.toLowerCase();
  for (final name in PassengerCarConfig.bodyTypes) {
    if (name.toLowerCase() == lower) return name;
  }
  if (lower == 'лифтбек') return 'Лифтбэк';
  if (lower == 'минивен') return 'Минивэн';
  return '';
}

String resolvePassengerBodyType(Map<String, dynamic> ad) {
  final fromApi = normalizePassengerBodyType('${ad['body_type'] ?? ''}');
  if (fromApi.isNotEmpty) return fromApi;
  return normalizePassengerBodyType(parseBodyTypeFromDescription('${ad['description'] ?? ''}'));
}
