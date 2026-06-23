// Профили «Электроника» — мисли frontend/src/utils/electronicsProfiles.js

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

bool isElectronicsCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return s == 'elektronika' || s.contains('elektronik');
}

const _electronicsPriceOnlyExact = {
  'zapchasti-i-instrumenty-dlya-telefonov',
  'remont-i-servis-telefonov',
  'drugaya-tehnika-svyazi',
  'igrovye-pristavkiprograma-i-igry',
  'planshety-i-bukridery',
  'printery-i-skanery',
  'monitory-i-proektory',
  'modemy-i-setevoe-oborudovanie',
  'komplektuyuschie-i-aksessuary-dlya-pk',
  'remont-pk-i-noutbukov',
  'servery',
  'prochie-dlya-pk',
  'foto-i-videokamery',
  'elektronnye-komponenty-i-radiodetali',
};

bool isElectronicsPriceOnlySlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  if (_electronicsPriceOnlyExact.contains(s)) return true;
  return s.contains('zapchasti-i-instrumenty-dlya-telefon') ||
      s.contains('remont-i-servis-telefon') ||
      s.contains('drugaya-tehnika-svyazi') ||
      s.contains('igrovye-pristav') ||
      s == 'planshety-i-bukridery' ||
      s.contains('planshety-i-bukrid') ||
      s.contains('printery-i-skaner') ||
      s.contains('monitory-i-proektor') ||
      s.contains('modemy-i-setevoe') ||
      s.contains('komplektuyuschie-i-aksessuary-dlya-pk') ||
      s.contains('remont-pk-i-noutbuk') ||
      s == 'servery' ||
      s.contains('prochie-dlya-pk') ||
      s.contains('foto-i-videokamer') ||
      s.contains('elektronnye-komponenty-i-radiodetali');
}

bool isPhoneListingSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty || isElectronicsPriceOnlySlug(s)) return false;
  if (s == 'telefony' || s == 'telefon') return true;
  if (s.startsWith('telefony-')) return true;
  if (s.contains('telefon') &&
      !s.contains('aksessuar') &&
      !s.contains('remont') &&
      !s.contains('zapchast') &&
      !s.contains('instrument')) {
    return true;
  }
  return false;
}

bool isLaptopListingSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty || isElectronicsPriceOnlySlug(s)) return false;
  if (s == 'noutbuki' || s == 'noutbuk') return true;
  if (s.startsWith('noutbuki-')) return true;
  if (s.contains('noutbuk') && !s.contains('remont-pk')) return true;
  return false;
}

bool isPhoneListingContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (!isElectronicsCategory(categorySlug)) return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isPhoneListingSlug);
}

bool isLaptopListingContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (!isElectronicsCategory(categorySlug)) return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isLaptopListingSlug);
}

const _electronicsConditionBoardExact = {
  'aksessuary-dlya-telefonov',
  'tv-dvd-i-video',
  'tehnika-dlya-doma-i-kuhni',
  'dlya-lichnogo-uhoda',
  'sistemy-videonablyudeniya-ohrany',
  'umnyy-dom',
  'klimaticheskaya-tehnika',
  'audio-i-stereo',
};

bool isElectronicsConditionBoardSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty || isElectronicsPriceOnlySlug(s)) return false;
  if (isPhoneListingSlug(s) || isLaptopListingSlug(s)) return false;
  if (_electronicsConditionBoardExact.contains(s)) return true;
  return (s.contains('aksessuar') && s.contains('telefon')) ||
      s.contains('tv-dvd') ||
      s.contains('televizor') ||
      s.contains('tehnika-dlya-doma') ||
      s.contains('tehnika-dlya-kuhni') ||
      s.contains('domashnyaya-tehnika') ||
      s.contains('lichnogo-uhoda') ||
      s.contains('individualnogo-uhoda') ||
      s.contains('videonablyuden') ||
      s.contains('sistemy-videonablyudeniya') ||
      s.contains('umnyy-dom') ||
      s.contains('umnyj-dom') ||
      s.contains('klimatichesk') ||
      s.contains('kondicion') ||
      s.contains('konditsion') ||
      s.contains('audio-i-stereo') ||
      (s.contains('audio') && s.contains('stereo'));
}

bool isElectronicsAdSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  if (isElectronicsCategory(s)) return true;
  if (isPhoneListingSlug(s) || isLaptopListingSlug(s)) return true;
  if (isElectronicsPriceOnlySlug(s) || isElectronicsConditionBoardSlug(s)) return true;
  return s.contains('elektronik') ||
      s.contains('klimatichesk') ||
      s.contains('kondicion') ||
      s.contains('konditsion');
}

bool isElectronicsAdContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isElectronicsAdSlug);
}

bool isElectronicsConditionBoardContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (!isElectronicsCategory(categorySlug)) return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isElectronicsConditionBoardSlug);
}

bool isElectronicsPriceOnlyContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (!isElectronicsCategory(categorySlug)) return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isElectronicsPriceOnlySlug);
}
