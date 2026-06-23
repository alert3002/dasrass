// Фильтры доски /ads — мисли frontend/src/utils/boardFilterConfig.js

import 'electronics_profiles.dart';
import 'passenger_car.dart';
import 'real_estate_profiles.dart';
import 'transport_profiles.dart';
import 'work_profiles.dart';
import 'clothing_profiles.dart';
import 'children_profiles.dart';
import 'services_profiles.dart';
import 'home_profiles.dart';
import 'construction_profiles.dart';
import 'catalog_profiles.dart';

class BoardFilterField {
  const BoardFilterField({
    required this.key,
    required this.label,
    required this.kind,
  });

  final String key;
  final String label;
  final BoardFilterKind kind;
}

enum BoardFilterKind {
  transmission,
  fuel,
  color,
  year,
  model,
  attr,
  volume,
  body,
  area,
  floor,
  condition,
  memory,
  size,
}

const fuelLabels = <String, String>{
  'diesel': 'Дизель',
  'gas': 'Газ',
  'petrol': 'Бензин',
  'electric': 'Электро',
};

const transmissionLabels = <String, String>{
  'manual': 'Механика',
  'automatic': 'Автомат',
};

const colorLabels = <String, String>{
  'white': 'Белый',
  'beige': 'Бежевый',
  'silver': 'Серебристый',
  'golden': 'Золотистый',
  'yellow': 'Жёлтый',
  'orange': 'Оранжевый',
  'red': 'Красный',
  'green': 'Зелёный',
  'light_blue': 'Голубой',
  'blue': 'Синий',
  'purple': 'Фиолетовый',
  'brown': 'Коричневый',
  'wet_asphalt': 'Мокрый асфальт',
  'black': 'Чёрный',
  'other': 'Другой цвет',
  'grey': 'Мокрый асфальт',
};

void mergeColorLabels(List<Map<String, String>> items) {
  for (final item in items) {
    final code = item['code']?.trim();
    final label = item['label']?.trim();
    if (code != null && code.isNotEmpty && label != null && label.isNotEmpty) {
      colorLabels[code] = label;
    }
  }
}

const allBoardFilterKeys = [
  'transmission',
  'fuel',
  'color',
  'year_min',
  'year_max',
  'volume_min',
  'volume_max',
  'area_min',
  'area_max',
  'floor_min',
  'floor_max',
  'body',
  'brand',
  'model',
  'memory',
  'ram',
  'type',
  'size',
  'condition',
  'experience',
  'salary',
  'services',
  'toys',
];

const _vehicleCategorySlugs = {
  'transport',
  'gruzoviki-avtobusy',
  'avtomobili-avtodoma-i-mototehnika',
};

const _partsTopCategorySlugs = {
  'zapchasti',
  'oborudovanie-zapchasti-uslugi',
};

const _passengerCarBoardFields = [
  BoardFilterField(key: 'year_min', label: 'Год от', kind: BoardFilterKind.year),
  BoardFilterField(key: 'year_max', label: 'Год до', kind: BoardFilterKind.year),
  BoardFilterField(key: 'volume_min', label: 'Объём от', kind: BoardFilterKind.volume),
  BoardFilterField(key: 'volume_max', label: 'Объём до', kind: BoardFilterKind.volume),
  BoardFilterField(key: 'body', label: 'Кузов', kind: BoardFilterKind.body),
];

const _motoBoardFields = [
  BoardFilterField(key: 'year_min', label: 'Год от', kind: BoardFilterKind.year),
  BoardFilterField(key: 'year_max', label: 'Год до', kind: BoardFilterKind.year),
  BoardFilterField(key: 'volume_min', label: 'Объём от', kind: BoardFilterKind.volume),
  BoardFilterField(key: 'volume_max', label: 'Объём до', kind: BoardFilterKind.volume),
];

const _vehicleFullFields = [
  BoardFilterField(key: 'transmission', label: 'Коробка передач', kind: BoardFilterKind.transmission),
  BoardFilterField(key: 'fuel', label: 'Вид топлива', kind: BoardFilterKind.fuel),
  BoardFilterField(key: 'color', label: 'Цвет', kind: BoardFilterKind.color),
  BoardFilterField(key: 'year_min', label: 'Год от', kind: BoardFilterKind.year),
  BoardFilterField(key: 'year_max', label: 'Год до', kind: BoardFilterKind.year),
];

const _realEstateYearFields = [
  BoardFilterField(key: 'year_min', label: 'Год постройки от', kind: BoardFilterKind.year),
  BoardFilterField(key: 'year_max', label: 'Год постройки до', kind: BoardFilterKind.year),
];

const _apartmentBoardFields = [
  BoardFilterField(key: 'area_min', label: 'Площадь от', kind: BoardFilterKind.area),
  BoardFilterField(key: 'area_max', label: 'Площадь до', kind: BoardFilterKind.area),
  BoardFilterField(key: 'floor_min', label: 'Этаж от', kind: BoardFilterKind.floor),
  BoardFilterField(key: 'floor_max', label: 'Этаж до', kind: BoardFilterKind.floor),
];

const deviceConditionOptions = ['Новый', 'Б/у'];

const phoneBoardFields = [
  BoardFilterField(key: 'condition', label: 'Состояние', kind: BoardFilterKind.condition),
  BoardFilterField(key: 'memory', label: 'Память', kind: BoardFilterKind.memory),
];

const laptopBoardFields = [
  BoardFilterField(key: 'condition', label: 'Состояние', kind: BoardFilterKind.condition),
  BoardFilterField(key: 'memory', label: 'Память', kind: BoardFilterKind.memory),
];

const electronicsConditionBoardFields = [
  BoardFilterField(key: 'condition', label: 'Состояние', kind: BoardFilterKind.condition),
];

const _phoneFields = [
  BoardFilterField(key: 'model', label: 'Модель', kind: BoardFilterKind.model),
  BoardFilterField(key: 'memory', label: 'Память', kind: BoardFilterKind.attr),
  BoardFilterField(key: 'ram', label: 'RAM', kind: BoardFilterKind.attr),
  BoardFilterField(key: 'color', label: 'Цвет', kind: BoardFilterKind.color),
];

const _phoneAccessoryFields = [
  BoardFilterField(key: 'model', label: 'Модель', kind: BoardFilterKind.model),
  BoardFilterField(key: 'color', label: 'Цвет', kind: BoardFilterKind.color),
];

const _laptopFields = [
  BoardFilterField(key: 'model', label: 'Модель', kind: BoardFilterKind.model),
  BoardFilterField(key: 'memory', label: 'Память', kind: BoardFilterKind.attr),
  BoardFilterField(key: 'color', label: 'Цвет', kind: BoardFilterKind.color),
];

const _tabletFields = [
  BoardFilterField(key: 'model', label: 'Модель', kind: BoardFilterKind.model),
  BoardFilterField(key: 'memory', label: 'Память', kind: BoardFilterKind.attr),
  BoardFilterField(key: 'ram', label: 'RAM', kind: BoardFilterKind.attr),
  BoardFilterField(key: 'color', label: 'Цвет', kind: BoardFilterKind.color),
];

const _childrenBoardFields = [
  BoardFilterField(key: 'condition', label: 'Состояние', kind: BoardFilterKind.condition),
];

const _homeBoardFields = [
  BoardFilterField(key: 'condition', label: 'Состояние', kind: BoardFilterKind.condition),
];

const _clothingAccessoryBoardFields = [
  BoardFilterField(key: 'condition', label: 'Состояние', kind: BoardFilterKind.condition),
];

const _clothingBoardFields = [
  BoardFilterField(key: 'condition', label: 'Состояние', kind: BoardFilterKind.condition),
  BoardFilterField(key: 'size', label: 'Размер', kind: BoardFilterKind.size),
];

final Map<String, List<BoardFilterField>> _slugFilterMap = {
  'planshety-i-bukrivery': _tabletFields,
};

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

bool _isRealEstateSlug(String slug) {
  final s = _norm(slug);
  return s.contains('nedvizhim') || s.contains('недвижим') || s.contains('novostroy');
}

bool _isRealEstateSlugForYearFilters(String slug) {
  final s = _norm(slug);
  return (s.contains('nedvizhim') || s.contains('недвижим'))
      && !isRealEstatePriceOnlySlug(s)
      && !isApartmentListingSlug(s);
}

bool _isPartsOrServiceSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return false;
  return s.contains('zapchast') ||
      s.contains('shiny') ||
      s.contains('disk') ||
      (s.contains('aksessuar') && s.contains('avto')) ||
      s.contains('prinadlezh') ||
      s == 'oborudovanie' ||
      s.contains('oborudovanie-zapchasti') ||
      (s == 'uslugi' && s.contains('avto')) ||
      s == 'arenda' ||
      s == 'kompanii';
}

bool _isVehicleUnitSlug(String slug) {
  final s = _norm(slug);
  if (s.isEmpty || _isPartsOrServiceSlug(s)) return false;
  return s.contains('legkovoy') ||
      s.contains('gruzovik') ||
      s.contains('tyagach') ||
      (s.contains('avtomobil') && !s.contains('zapchast')) ||
      s.contains('mototehn') ||
      s.contains('avtobus') ||
      s.contains('mikroavtobus') ||
      s.contains('pricep') ||
      s.contains('polupricep') ||
      s.contains('tsister') ||
      s.contains('kemper') ||
      s.contains('kommerchesk') ||
      s.contains('kommunal') ||
      s.contains('aerodrom') ||
      s.contains('zheleznodorozh') ||
      s.contains('konteyner') ||
      s.contains('vodnyy') ||
      s.contains('vozdushnyy');
}

List<BoardFilterField>? _matchFieldsBySlugPattern(String slug) {
  final s = _norm(slug);
  if (s.isEmpty) return null;
  if (isElectronicsPriceOnlySlug(s)) return null;
  if (isPhoneListingSlug(s) || isLaptopListingSlug(s)) return null;
  if (isElectronicsConditionBoardSlug(s)) return null;
  if (_isRealEstateSlugForYearFilters(s)) return _realEstateYearFields;
  if ((s.contains('planshet') || s.contains('bukrider') || s.contains('bukrivery'))
      && !isElectronicsPriceOnlySlug(s)) {
    return _tabletFields;
  }
  if (isChildrenBoardSlug(s)) return null;
  if (isHomeBoardSlug(s)) return null;
  if (isConstructionBoardSlug(s)) return null;
  if (isCatalogBoardSlug(s)) return null;
  if (isWorkSlug(s)) return null;
  if (isClothingBoardSlug(s) || isClothingAccessoryBoardSlug(s)) return null;
  return null;
}

List<BoardFilterField>? _resolveCustomFilterFields(
  String? categorySlug,
  String? subcategorySlug,
  List<String> subcategoryPathSlugs,
) {
  final catNorm = _norm(categorySlug);
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  for (final slug in slugs) {
    if (catNorm.isNotEmpty && _norm(slug) == catNorm) continue;
    final exact = _slugFilterMap[slug];
    if (exact != null) return exact;
  }
  for (final slug in slugs) {
    if (catNorm.isNotEmpty && _norm(slug) == catNorm) continue;
    final matched = _matchFieldsBySlugPattern(slug);
    if (matched != null) return matched;
  }
  return null;
}

bool isTransportCategory(String? categorySlug) {
  final s = _norm(categorySlug);
  if (s.isEmpty) return false;
  if (_vehicleCategorySlugs.contains(s)) return true;
  if (s.contains('transport') || s.contains('транспорт')) return true;
  return false;
}

List<String> subcategoryPathSlugsFromNodes(List<Map<String, dynamic>> path) {
  return path.map((n) => '${n['slug'] ?? ''}').where((s) => s.isNotEmpty).toList();
}

List<BoardFilterField> getBoardFilterFields(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (isPassengerCarContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return _passengerCarBoardFields;
  }
  if (isMotoTransportContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return _motoBoardFields;
  }
  if (isApartmentListingContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return _apartmentBoardFields;
  }
  if (isPhoneListingContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return phoneBoardFields;
  }
  if (isLaptopListingContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return laptopBoardFields;
  }
  if (isElectronicsConditionBoardContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return electronicsConditionBoardFields;
  }
  if (isChildrenBoardContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return _childrenBoardFields;
  }
  if (isHomeBoardContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return _homeBoardFields;
  }
  if (isClothingAccessoryBoardContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return _clothingAccessoryBoardFields;
  }
  if (isClothingBoardContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return _clothingBoardFields;
  }
  if (isBoardPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return const [];
  }
  if (isRealEstateCategory(categorySlug) &&
      _norm(subcategorySlug).isEmpty &&
      subcategoryPathSlugs.isEmpty) {
    return const [];
  }
  if (isElectronicsCategory(categorySlug) &&
      _norm(subcategorySlug).isEmpty &&
      subcategoryPathSlugs.isEmpty) {
    return const [];
  }
  if (isWorkCategory(categorySlug) &&
      _norm(subcategorySlug).isEmpty &&
      subcategoryPathSlugs.isEmpty) {
    return const [];
  }
  if (isClothingCategory(categorySlug) &&
      _norm(subcategorySlug).isEmpty &&
      subcategoryPathSlugs.isEmpty) {
    return const [];
  }
  if (isChildrenCategory(categorySlug) &&
      _norm(subcategorySlug).isEmpty &&
      subcategoryPathSlugs.isEmpty) {
    return const [];
  }
  if (isServicesCategory(categorySlug) &&
      _norm(subcategorySlug).isEmpty &&
      subcategoryPathSlugs.isEmpty) {
    return const [];
  }
  if (isHomeCategory(categorySlug) &&
      _norm(subcategorySlug).isEmpty &&
      subcategoryPathSlugs.isEmpty) {
    return const [];
  }
  if (isConstructionCategory(categorySlug) &&
      _norm(subcategorySlug).isEmpty &&
      subcategoryPathSlugs.isEmpty) {
    return const [];
  }
  if ((isAnimalsCategory(categorySlug) ||
          isBusinessCategory(categorySlug) ||
          isHobbyCategory(categorySlug)) &&
      _norm(subcategorySlug).isEmpty &&
      subcategoryPathSlugs.isEmpty) {
    return const [];
  }

  final custom = _resolveCustomFilterFields(categorySlug, subcategorySlug, subcategoryPathSlugs);
  if (custom != null) return custom;

  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  for (final slug in slugs) {
    if (_isPartsOrServiceSlug(slug)) return const [];
  }
  for (final slug in slugs) {
    if (_isVehicleUnitSlug(slug)) return _vehicleFullFields;
  }
  final cat = _norm(categorySlug);
  if (_partsTopCategorySlugs.contains(cat)) return const [];
  if (_vehicleCategorySlugs.contains(cat) || isTransportCategory(categorySlug)) {
    if (_norm(subcategorySlug).isEmpty) return const [];
    return _vehicleFullFields;
  }
  if (isRealEstateCategory(categorySlug)) return _realEstateYearFields;
  return const [];
}

bool boardShowsBrandFilters(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  if (isBoardPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return false;
  }
  if (isPhoneListingContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isLaptopListingContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return true;
  }
  final fields = getBoardFilterFields(categorySlug, subcategorySlug, subcategoryPathSlugs);
  if (fields.any((f) => f.kind == BoardFilterKind.model)) return true;
  if (isPassengerCarContext(categorySlug, subcategorySlug, subcategoryPathSlugs) ||
      isMotoTransportContext(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    return true;
  }
  final slugs = _buildSlugList(categorySlug, subcategorySlug, subcategoryPathSlugs);
  for (final slug in slugs) {
    if (_isVehicleUnitSlug(slug)) return true;
  }
  return false;
}

bool boardUsesFilterOptionsApi(
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final fields = getBoardFilterFields(categorySlug, subcategorySlug, subcategoryPathSlugs);
  if (fields.any((f) => f.kind == BoardFilterKind.model || f.kind == BoardFilterKind.color)) {
    return true;
  }
  return boardShowsBrandFilters(categorySlug, subcategorySlug, subcategoryPathSlugs);
}

Map<String, String> pruneBoardFilters(
  Map<String, String> filters,
  String? categorySlug,
  String? subcategorySlug, [
  List<String> subcategoryPathSlugs = const [],
]) {
  final allowed = getBoardFilterFields(categorySlug, subcategorySlug, subcategoryPathSlugs)
      .map((f) => f.key)
      .toSet();
  final next = Map<String, String>.from(filters);
  for (final key in allBoardFilterKeys) {
    if (!allowed.contains(key)) next[key] = '';
  }
  if (!boardShowsBrandFilters(categorySlug, subcategorySlug, subcategoryPathSlugs)) {
    next['brand'] = '';
    if (!allowed.contains('model')) next['model'] = '';
  }
  return next;
}
