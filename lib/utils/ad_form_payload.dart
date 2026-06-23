import 'ad_field_config.dart';
import 'catalog_profiles.dart';
import 'clothing_profiles.dart';
import 'children_profiles.dart';
import 'construction_profiles.dart';
import 'electronics_profiles.dart';
import 'home_profiles.dart';
import 'passenger_car.dart';
import 'real_estate_profiles.dart';
import 'services_profiles.dart';
import 'transport_profiles.dart';

/// Собирает поля для `createAd` — мисли [AddAd.jsx] `handleSubmit`.
Map<String, String> buildAdCreatePayload({
  required String categorySlug,
  required String subcategorySlug,
  required List<String> subcategoryPath,
  required List<dynamic>? subcategoryRoots,
  required String title,
  required String description,
  required String city,
  required String priceType,
  required String price,
  required String currency,
  required String? tariffId,
  required Map<String, String> dynamicValues,
  required String bodyType,
}) {
  final payload = <String, String>{
    'category': categorySlug,
    'subcategory': subcategorySlug,
    'title': title,
    'description': description,
    'city': city,
    'priceType': priceType,
    'currency': currency,
    ...dynamicValues,
  };
  if (priceType == 'fixed') payload['price'] = price;
  if (tariffId != null && tariffId.isNotEmpty) payload['tariff'] = tariffId;

  final fromPath = passengerCarBrandModelFromPath(subcategoryRoots, subcategoryPath);
  if (fromPath != null) {
    if (fromPath.brand.isNotEmpty) payload['brand'] = fromPath.brand;
    if (fromPath.model.isNotEmpty) payload['model'] = fromPath.model;
  }

  final isPassengerCar = isPassengerCarContext(categorySlug, subcategorySlug, subcategoryPath);
  final isCommercial =
      isCommercialTransportContext(categorySlug, subcategorySlug, subcategoryPath);
  final isApartment = isApartmentListingContext(categorySlug, subcategorySlug, subcategoryPath);
  final isElectronicsPriceOnly =
      isElectronicsPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPath);
  final isPhone = isPhoneListingContext(categorySlug, subcategorySlug, subcategoryPath);
  final isLaptop = isLaptopListingContext(categorySlug, subcategorySlug, subcategoryPath);
  final isElectronicsCondition =
      isElectronicsConditionBoardContext(categorySlug, subcategorySlug, subcategoryPath);
  final isClothing = isClothingBoardContext(categorySlug, subcategorySlug, subcategoryPath);
  final isClothingAccessory =
      isClothingAccessoryBoardContext(categorySlug, subcategorySlug, subcategoryPath);
  final isChildren = isChildrenBoardContext(categorySlug, subcategorySlug, subcategoryPath);
  final isHome = isHomeBoardContext(categorySlug, subcategorySlug, subcategoryPath);
  final isConstruction =
      isConstructionPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPath);
  final isServices = isServicesPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPath);
  final isCatalog = isCatalogPriceOnlyContext(categorySlug, subcategorySlug, subcategoryPath);

  var desc = description;
  if (isPassengerCar && bodyType.trim().isNotEmpty) {
    desc = prependBodyToDescription(desc, bodyType);
  }
  if (isCommercial && (payload['type'] ?? '').trim().isNotEmpty) {
    desc = prependVehicleTypeToDescription(desc, payload['type']!.trim());
  }

  if (isApartment) {
    final areaNum = int.tryParse('${payload['area'] ?? ''}'.replaceAll(RegExp(r'\D'), ''));
    if (areaNum != null && areaNum > 0) {
      payload['mileage'] = '$areaNum';
      payload['capacity'] = '$areaNum м²';
    }
    final floorNum = int.tryParse('${payload['floor'] ?? ''}'.replaceAll(RegExp(r'\D'), ''));
    if (floorNum != null && floorNum > 0) payload['year'] = '$floorNum';
    if ((payload['rooms'] ?? '').isNotEmpty) payload['model'] = payload['rooms']!;
  }

  if (isElectronicsPriceOnly ||
      isPhone ||
      isLaptop ||
      isElectronicsCondition ||
      isClothing ||
      isClothingAccessory ||
      isChildren) {
    if ((payload['memory'] ?? '').isNotEmpty) {
      payload['capacity'] = payload['memory']!.trim();
    }
    final specLines = <String>[];
    void add(String key, String label) {
      final v = (payload[key] ?? '').trim();
      if (v.isNotEmpty) specLines.add('$label: $v');
    }

    add('condition', 'Состояние');
    add('size', 'Размер');
    final itemType = (payload['type'] ?? payload['toys'] ?? '').trim();
    if (itemType.isNotEmpty) specLines.add('Тип: $itemType');
    add('memory', 'Память');
    add('ram', 'RAM');
    if (specLines.isNotEmpty) {
      final prefix = specLines.join('\n');
      desc = desc.isEmpty ? prefix : '$prefix\n\n$desc';
    }
  }

  if (isHome) {
    final specLines = <String>[];
    for (final e in homeSpecLabels.entries) {
      final v = (payload[e.key] ?? '').trim();
      if (v.isNotEmpty) specLines.add('${e.value}: $v');
    }
    if (specLines.isNotEmpty) {
      final prefix = specLines.join('\n');
      desc = desc.isEmpty ? prefix : '$prefix\n\n$desc';
    }
  }

  if (isConstruction) {
    final specLines = <String>[];
    for (final f in getConstructionCharacteristicFields(categorySlug, subcategorySlug, subcategoryPath)) {
      final v = (payload[f.key] ?? '').trim();
      if (v.isNotEmpty) specLines.add('${f.label}: $v');
    }
    if (specLines.isNotEmpty) {
      final prefix = specLines.join('\n');
      desc = desc.isEmpty ? prefix : '$prefix\n\n$desc';
    }
  }

  if (isServices) {
    final specLines = <String>[];
    for (final e in serviceSpecLabels.entries) {
      final v = (payload[e.key] ?? '').trim();
      if (v.isNotEmpty) specLines.add('${e.value}: $v');
    }
    if (specLines.isNotEmpty) {
      final prefix = specLines.join('\n');
      desc = desc.isEmpty ? prefix : '$prefix\n\n$desc';
    }
  }

  if (isCatalog) {
    final specLines = <String>[];
    for (final f in getCatalogCharacteristicFields(categorySlug, subcategorySlug, subcategoryPath)) {
      final v = (payload[f.key] ?? '').trim();
      if (v.isNotEmpty) specLines.add('${f.label}: $v');
    }
    if (specLines.isNotEmpty) {
      final prefix = specLines.join('\n');
      desc = desc.isEmpty ? prefix : '$prefix\n\n$desc';
    }
  }

  payload['description'] = desc;

  // Map engine_volume subcategory field to capacity if needed
  if ((payload['engine_volume'] ?? '').isNotEmpty && (payload['capacity'] ?? '').isEmpty) {
    payload['capacity'] = payload['engine_volume']!;
  }

  const stripKeys = {
    'body_type',
    'type',
    'area',
    'floor',
    'rooms',
    'memory',
    'ram',
    'condition',
    'size',
    'toys',
    'service_area',
    'experience',
    'deadline',
    'languages',
    'material',
    'unit',
    'breed',
    'age',
    'gender',
    'revenue',
    'event_date',
    'engine_volume',
  };
  for (final k in stripKeys) {
    payload.remove(k);
  }

  return payload;
}

String? validateDynamicFields(List<AdDynamicField> fields, Map<String, String> values) {
  for (final f in fields) {
    if (f.hidden) continue;
    if (!f.required) continue;
    final v = (values[f.key] ?? '').trim();
    if (v.isEmpty) return 'Заполните поле «${f.label}»';
  }
  return null;
}
