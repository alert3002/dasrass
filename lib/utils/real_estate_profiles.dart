// Профили недвижимости — мисли frontend/src/utils/realEstateProfiles.js

import 'electronics_profiles.dart';
import 'transport_profiles.dart';
import 'work_profiles.dart';
import 'services_profiles.dart';
import 'construction_profiles.dart';
import 'catalog_profiles.dart';

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

bool isRealEstateCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  return s == 'nedvizhimsot' || s.contains('nedvizhim');
}

const _realEstatePriceOnlyExact = {
  'novostroyki',
  'arenda-komnat',
  'arenda-dacha',
  'arenda-domov-havli',
  'arenda-ofisov-i-pomeshenie',
  'posutochnaya-arenda-kvartir-domov-i-hostel',
  'prodazha-domov-havli-i-dach',
  'prodazha-arenda-garazhey-i-stoyanok',
  'prodazha-arenda-postroek-s-zemelnym-uchastkom',
};

bool isRealEstatePriceOnlySlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  if (_realEstatePriceOnlyExact.contains(s)) return true;
  return s.contains('novostroy') ||
      s.contains('arenda-komnat') ||
      (s.contains('arenda-dach') && !s.contains('kvartir')) ||
      s.contains('garazh') ||
      s.contains('stoyanok') ||
      s.contains('prodazha-ofis') ||
      s.contains('arenda-ofis') ||
      (s.contains('pomeshen') && !s.contains('kvartir')) ||
      s.contains('otdelno-stoy') ||
      s.contains('stoyashchih-zdan') ||
      s.contains('posutochn') ||
      s.contains('hostel') ||
      s.contains('prodazha-domov-havli') ||
      s.contains('arenda-domov-havli') ||
      s.contains('vagonchik') ||
      s.contains('bytovok') ||
      s.contains('vagon-dom') ||
      s.contains('postroek-s-zemel') ||
      s.contains('zemelnym-uchastkom') ||
      s.contains('gostinic') ||
      s.contains('gostinits') ||
      s.contains('otel');
}

bool isRealEstatePriceOnlyContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (!isRealEstateCategory(categorySlug)) return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isRealEstatePriceOnlySlug);
}

bool isApartmentListingSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  if (s.contains('posutochn') || s.contains('hostel')) return false;
  if (s == 'arenda-kvartir' || s == 'prodazha-kvartir') return true;
  if (s.contains('prodazha-kvartir')) return true;
  if (s.contains('arenda-kvartir') && !s.contains('domov')) return true;
  return false;
}

bool isApartmentListingContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (!isRealEstateCategory(categorySlug)) return false;
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  return slugs.any(isApartmentListingSlug);
}

bool isBoardPriceOnlyContext(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  return isCityPriceOnlyBoardContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isRealEstatePriceOnlyContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isElectronicsPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isWorkPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isServicesPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isConstructionPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isCatalogPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPathSlugs);
}
