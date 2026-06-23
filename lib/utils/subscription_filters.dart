import 'dart:convert';

import 'board_filter_config.dart';

const subscriptionFilterKeys = [
  'category',
  'subcategory',
  'q',
  'city',
  'price_min',
  'price_max',
  'tonnage',
  ...allBoardFilterKeys,
];

Map<String, String> filtersToSubscriptionPayload(Map<String, String> filters) {
  final out = <String, String>{};
  for (final key in subscriptionFilterKeys) {
    final v = (filters[key] ?? '').trim();
    if (v.isNotEmpty) out[key] = v;
  }
  return out;
}

bool canSubscribeToFilters(Map<String, String> filters) {
  final category = (filters['category'] ?? '').trim();
  final subcategory = (filters['subcategory'] ?? '').trim();
  // Танҳо подкатегория / раздел / подраздел — на категорияи асосӣ не.
  return category.isNotEmpty && subcategory.isNotEmpty;
}

String filtersSignature(Map<String, String> filters) => _signatureJson(filters);

bool isSubscribedToFilters(
  List<Map<String, dynamic>> subscriptions,
  Map<String, String> filters,
) {
  final sig = _signatureJson(filters);
  if (sig.isEmpty) return false;
  for (final sub in subscriptions) {
    final raw = sub['filters'];
    if (raw is! Map) continue;
    final existing = <String, String>{};
    raw.forEach((k, v) {
      final s = '$v'.trim();
      if (s.isNotEmpty) existing['$k'] = s;
    });
    if (_signatureJson(existing) == sig) return true;
  }
  return false;
}

String _signatureJson(Map<String, String> filters) {
  final norm = filtersToSubscriptionPayload(filters);
  if (norm.isEmpty) return '';
  final keys = norm.keys.toList()..sort();
  final sorted = <String, String>{for (final k in keys) k: norm[k]!};
  return jsonEncode(sorted);
}
