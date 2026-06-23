// «Строительство» — мисли constructionProfiles.js

String _norm(String? slug) => (slug ?? '').trim().toLowerCase();

List<String> _buildSlugList(
  String? categorySlug,
  String? subcategorySlug,
  List<String> subcategoryPathSlugs,
) {
  final path = subcategoryPathSlugs;
  return {
    if (_norm(subcategorySlug).isNotEmpty) _norm(subcategorySlug),
    ...path.reversed.map(_norm).where((s) => s.isNotEmpty),
    if (_norm(categorySlug).isNotEmpty) _norm(categorySlug),
  }.toList();
}

bool isConstructionCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return s == 'stritelstvo' || s.contains('stritelstvo');
}

bool isConstructionBoardSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  if (isConstructionCategory(s)) return true;
  return s.contains('stroitelnye-i-otdelochnye-materialy') ||
      s.contains('otdelochnye-materialy') ||
      s.contains('elektroinstrument') ||
      s.contains('ruchnoy-instrument') ||
      s == 'drugoy';
}

bool isConstructionPriceOnlyContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  return isConstructionCategory(categorySlug);
}

bool isConstructionAdContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  return isConstructionCategory(categorySlug);
}
