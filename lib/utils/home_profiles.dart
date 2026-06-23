// «Все для дома» — мисли homeProfiles.js

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

bool isHomeCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return s == 'vse-dlya-doma' || s.contains('vse-dlya-doma');
}

const _homeRootSlugs = {
  'mebel',
  'tekstil-i-interer',
  'pischevye-produkty',
  'posuda-i-kuhonnaya-utvar',
  'hozyaystvennyy-inventar-i-bytovaya-himiya',
  'sad-i-ogorod',
  'seyfy',
  'kantstovary',
  'drugie-tovary-dlya-doma',
  'tovary-dlya-prazdnikov',
};

bool isHomeBoardSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  if (isHomeCategory(s)) return true;
  if (_homeRootSlugs.contains(s)) return true;
  return s.startsWith('mebel-') ||
      s.contains('tekstil-i-interer') ||
      s.contains('pischevye-produkt') ||
      s.contains('posuda-i-kuhonn') ||
      s.contains('hozyaystvennyy-inventar') ||
      s.contains('bytovaya-himiya') ||
      s.contains('sad-i-ogorod') ||
      s.contains('seyf') ||
      s.contains('kantstovar') ||
      s.contains('tovary-dlya-doma') ||
      s.contains('tovary-dlya-prazdnikov');
}

bool isHomeBoardContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (!isHomeCategory(categorySlug)) return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isHomeBoardSlug);
}

bool isHomeAdContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  return isHomeBoardContext(categorySlug, subcategorySlug, subcategoryPathSlugs);
}
