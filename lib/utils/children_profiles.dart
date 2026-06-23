// «Детский мир» — мисли childrenProfiles.js

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

bool isChildrenCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return s == 'detskij-mir' ||
      s == 'detskiy-mir' ||
      s == 'detskii-mir' ||
      s.contains('detskij-mir') ||
      s.contains('detskiy-mir') ||
      s.contains('detskii-mir');
}

bool isChildrenBoardSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  if (isChildrenCategory(s)) return true;
  return s.contains('detsk') ||
      s.contains('detskaya') ||
      s.contains('detskie') ||
      s.contains('igrushk') ||
      s.contains('kolyask') ||
      s.contains('kachel') ||
      s.contains('avtokresl') ||
      s.contains('kupaniya');
}

bool isChildrenBoardContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isChildrenBoardSlug);
}
