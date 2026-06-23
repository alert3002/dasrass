/// Только город / район — без названия области (Согд — Ашт → Ашт).
String shortLocalityLabel(String? text) {
  final s = (text ?? '').trim();
  if (s.isEmpty) return '';
  final parts = s
      .split(RegExp(r'\s*[—–-]\s*'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length > 1) return parts.last;
  final comma = s.split(',').first.trim();
  return comma.isEmpty ? s : comma;
}

String localitySelectLabel(Map<String, dynamic> row) {
  final name = '${row['name'] ?? ''}'.trim();
  if (name.isNotEmpty) return name;
  return shortLocalityLabel('${row['full_label'] ?? ''}');
}

/// Области-контейнеры (Согд, Хатлон…) не показываем в селектах.
List<Map<String, dynamic>> selectableLocalities(List<Map<String, dynamic>> flat) {
  final parentIds = flat
      .map((r) => r['parent_id'])
      .where((id) => id != null)
      .map((id) => '$id')
      .toSet();
  return flat.where((row) => !parentIds.contains('${row['id']}')).toList();
}
