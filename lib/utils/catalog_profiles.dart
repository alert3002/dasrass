// Животные и растения, Все для бизнеса, Хобби — мисли catalogProfiles.js

const animalsCategorySlug = 'zhivotnye-i-rasteniya';
const businessCategorySlug = 'vse-dlya-biznes';
const hobbyCategorySlug = 'hobbi-muzyka-i-sport';

final _catalogCategorySlugs = {
  animalsCategorySlug,
  businessCategorySlug,
  hobbyCategorySlug,
};

String _norm(String? slug) => (slug ?? '').trim().toLowerCase();

bool isAnimalsCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return s == animalsCategorySlug || s.contains('zhivotnye-i-rasten');
}

bool isBusinessCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return s == businessCategorySlug || s.contains('vse-dlya-biznes');
}

bool isHobbyCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return s == hobbyCategorySlug || s.contains('hobbi-muzyka-i-sport');
}

bool isCatalogPriceOnlyCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return _catalogCategorySlugs.contains(s) ||
      isAnimalsCategory(s) ||
      isBusinessCategory(s) ||
      isHobbyCategory(s);
}

bool isCatalogBoardSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  if (isAnimalsCategory(s)) return true;
  if (isBusinessCategory(s)) return true;
  if (isHobbyCategory(s)) return true;
  return s.contains('zhivotn') ||
      s.contains('sobak') ||
      s.contains('koshk') ||
      s.contains('krolik') ||
      s.contains('ptits') ||
      s.contains('vyazk') ||
      s.contains('rasten') ||
      s.contains('selhoz') ||
      s.contains('akvarium') ||
      s.contains('korm-dlya') ||
      s.contains('pchelovod') ||
      s.contains('uteryann') ||
      s == 'otdam-darom' ||
      s.contains('oborudovanie') ||
      s.contains('syryo-i-materialy') ||
      s.contains('biznes-na-prodazhu') ||
      s.contains('gotovyy-biznes') ||
      s.contains('biznes-v-arendu') ||
      s.contains('sport-i-inventar') ||
      s.contains('velosiped') ||
      s.contains('muzykalnye-instrument') ||
      s.contains('knigi-i-zhurnal') ||
      s.contains('antikvariat') ||
      s.contains('kollektsii') ||
      s.contains('cd-dvd') ||
      s.contains('plastinki') ||
      s == 'bilety';
}

bool isCatalogPriceOnlyContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  return isCatalogPriceOnlyCategory(categorySlug);
}

bool isCatalogAdContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  return isCatalogPriceOnlyCategory(categorySlug);
}
