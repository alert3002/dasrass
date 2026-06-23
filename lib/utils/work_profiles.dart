// Категория «Работа» — на доске только Город + Цена (мисли workProfiles.js)

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

bool isWorkSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  return s == 'rabota' ||
      s.contains('rabota') ||
      s.contains('zanyatost') ||
      s.contains('personnel') ||
      s.contains('vakans');
}

bool isWorkCategory(String? categorySlug) => isWorkSlug(categorySlug ?? '');

bool isWorkPriceOnlyContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isWorkSlug);
}
