// Профили транспорта — мисли frontend/src/utils/transportProfiles.js

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

const _partsCategorySlugs = {'zapchasti', 'oborudovanie-zapchasti-uslugi'};

bool _isPartsSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  return s.contains('zapchast') ||
      s.contains('shiny') ||
      s.contains('disk') ||
      (s.contains('aksessuar') && s.contains('avto')) ||
      s.contains('prinadlezh') ||
      s == 'oborudovanie' ||
      s.contains('oborudovanie-zapchasti');
}

bool isMotoTransportContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (_norm(categorySlug) != 'transport') return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(
    (s) =>
        s.contains('moto-transport') ||
        s.contains('mototransport') ||
        (s.contains('moto') && !s.contains('legkovoy') && !s.contains('kommerch')) ||
        s.contains('mototehn') ||
        s.contains('moped') ||
        s.contains('skuter') ||
        s.contains('motocikl') ||
        s.contains('kvadrocikl') ||
        s.contains('motogruz'),
  );
}

bool isCommercialTransportContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (_norm(categorySlug) != 'transport') return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(
    (s) =>
        s.contains('kommerch') ||
        s.contains('selhoz') ||
        s.contains('gruzovik') ||
        s.contains('tyagach') ||
        s.contains('stroitel') ||
        s.contains('spec-tehn') ||
        s.contains('selskohoz') ||
        (s.contains('avtobus') &&
            !isMotoTransportContext(categorySlug, subcategorySlug, subcategoryPathSlugs)),
  );
}

bool isPartsAccessoriesContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final cat = _norm(categorySlug);
  if (_partsCategorySlugs.contains(cat)) return true;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(_isPartsSlug);
}

bool _isSimpleTransportListingSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  return s == 'avtoservis-i-remont' ||
      s.contains('avtoservis') ||
      s == 'printsepy-i-konteynery' ||
      s.contains('printsep') ||
      s.contains('pricep') ||
      s.contains('polupricep') ||
      s.contains('konteyner') ||
      s == 'drugoy-transport' ||
      s.contains('drugoy-transport');
}

bool isSimpleTransportListingContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (_norm(categorySlug) != 'transport') return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(_isSimpleTransportListingSlug);
}

bool isCityPriceOnlyBoardContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  return isCommercialTransportContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isPartsAccessoriesContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isSimpleTransportListingContext(categorySlug, subcategorySlug, subcategoryPathSlugs);
}
