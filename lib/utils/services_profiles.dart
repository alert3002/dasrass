// Категория «Услуги» — мисли servicesProfiles.js

String _norm(String? slug) => (slug ?? '').trim().toLowerCase();

bool isServicesCategory(String? categorySlug) => _norm(categorySlug) == 'uslugi';

bool isServicesPriceOnlyContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  return isServicesCategory(categorySlug);
}

String resolveServicesSubSlug(
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final path = subcategoryPathSlugs;
  final slugs = {
    if (_norm(subcategorySlug).isNotEmpty) _norm(subcategorySlug),
    ...path.reversed.map(_norm).where((s) => s.isNotEmpty),
    'uslugi',
  }.toList();
  for (final s in slugs) {
    if (s != 'uslugi') return s;
  }
  return _norm(subcategorySlug);
}
