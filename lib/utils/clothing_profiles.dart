// «Одежда и вещи» — мисли clothingProfiles.js

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

bool isClothingCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return s.contains('odezhda') ||
      s.contains('odezhda-i-vesh') ||
      s.contains('odezhda-i-veshi') ||
      s.contains('veshch') ||
      s.contains('veshi');
}

const _clothingAccessoryExact = {
  'aksessuary-sharfy-golovnye-ubory',
  'chasy-i-ukrasheniya',
  'dlya-svadba',
};

bool isClothingAccessoryBoardSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  if (_clothingAccessoryExact.contains(s)) return true;
  return s.contains('aksessuary-sharfy') ||
      s.contains('sharfy-golovnye') ||
      s.contains('golovnye-ubor') ||
      s.contains('chasy-i-ukrashen') ||
      s.startsWith('chasy-i-ukrasheniya-') ||
      s == 'dlya-svadba' ||
      s.contains('dlya-svad');
}

bool isClothingAccessoryBoardContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isClothingAccessoryBoardSlug);
}

bool isClothingBoardSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty || isClothingAccessoryBoardSlug(s)) return false;
  if (s.contains('odezhda') ||
      s.contains('odezhda-i-vesh') ||
      s.contains('odezhda-i-veshi') ||
      s.contains('veshch') ||
      s.contains('veshi')) {
    return true;
  }
  if (s.contains('muzhskaya') && s.contains('odezhd')) return true;
  if (s.contains('zhenskaya') && s.contains('odezhd')) return true;
  if (s == 'obuv' || s.startsWith('obuv-') || (s.contains('obuv') && !s.contains('avto'))) {
    return true;
  }
  if (s.contains('sumk') ||
      s.contains('chemodan') ||
      s.contains('platye') ||
      s.contains('kurtka')) {
    return true;
  }
  return false;
}

bool isClothingBoardContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isClothingBoardSlug);
}
