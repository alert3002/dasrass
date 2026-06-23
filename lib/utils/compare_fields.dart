import '../widgets/dastrass_ad_listing_card.dart';
import '../utils/locality_label.dart';
import 'board_filter_config.dart';
import 'color_catalog.dart';
import 'passenger_car.dart';
import 'electronics_profiles.dart';
import 'clothing_profiles.dart';
import 'children_profiles.dart';
import 'services_profiles.dart';
import 'home_profiles.dart';
import 'construction_profiles.dart';
import 'catalog_profiles.dart';
import 'real_estate_profiles.dart';
import 'transport_profiles.dart';

import 'work_profiles.dart';

const compareEmptyCategoryHint =
    'У этой категории сейчас нет сравнения. Можно добавить из избранного.';

/// Строки и профили таблицы сравнения (как [frontend/src/utils/compareFields.js]).
enum CompareProfile {
  transport,
  realEstate,
  electronics,
  home,
  construction,
  catalog,
  services,
  children,
  clothing,
  work,
  generic,
}

CompareProfile inferCompareProfile(String? categorySlug, [String? subcategorySlug]) {
  final cat = (categorySlug ?? '').trim().toLowerCase();
  final slugs = [
    (subcategorySlug ?? '').trim().toLowerCase(),
    cat,
  ].where((s) => s.isNotEmpty);
  for (final s in slugs) {
    if (s.contains('nedvizhim') || s.contains('недвижим') || s.contains('novostroy')) {
      return CompareProfile.realEstate;
    }
  }
  if (isTransportCategory(categorySlug) ||
      slugs.any((s) => s.contains('transport') || s.contains('legkovoy') || s.contains('gruzovik'))) {
    return CompareProfile.transport;
  }
  if (isElectronicsCategory(categorySlug) || isElectronicsAdContext(categorySlug, subcategorySlug)) {
    return CompareProfile.electronics;
  }
  if (isHomeCategory(categorySlug)) return CompareProfile.home;
  if (isConstructionCategory(categorySlug)) return CompareProfile.construction;
  if (isCatalogPriceOnlyCategory(categorySlug)) return CompareProfile.catalog;
  if (isServicesCategory(categorySlug)) return CompareProfile.services;
  if (isChildrenCategory(categorySlug)) return CompareProfile.children;
  if (isClothingCategory(categorySlug)) return CompareProfile.clothing;
  if (isWorkCategory(categorySlug)) return CompareProfile.work;
  return isTransportCategory(categorySlug) ? CompareProfile.generic : CompareProfile.catalog;
}

CompareProfile profileForCategorySlug(String? slug) => inferCompareProfile(slug, '');

CompareProfile dominantProfile(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return CompareProfile.transport;
  final counts = <CompareProfile, int>{};
  for (final ad in items) {
    final p = inferCompareProfile(
      '${ad['category_slug'] ?? ''}',
      '${ad['subcategory_slug'] ?? ''}',
    );
    counts[p] = (counts[p] ?? 0) + 1;
  }
  CompareProfile best = CompareProfile.generic;
  var max = 0;
  counts.forEach((p, n) {
    if (n > max) {
      max = n;
      best = p;
    }
  });
  return best;
}

List<Map<String, dynamic>> filterItemsByProfile(
  List<Map<String, dynamic>> items,
  CompareProfile profile,
) {
  return items
      .where(
        (ad) =>
            inferCompareProfile(
              '${ad['category_slug'] ?? ''}',
              '${ad['subcategory_slug'] ?? ''}',
            ) ==
            profile,
      )
      .toList();
}

class CompareRow {
  const CompareRow(this.label, this.get);
  final String label;
  final String Function(Map<String, dynamic> ad) get;
}

const _fuelLabels = {
  'diesel': 'Дизель',
  'gas': 'Газ',
  'petrol': 'Бензин',
  'electric': 'Электро',
};
const _transLabels = {
  'manual': 'Механика',
  'automatic': 'Автомат',
};

String _colorLabelFromCode(String code, {String empty = '—'}) {
  final c = code.trim();
  if (c.isEmpty) return empty;
  final label = ColorCatalog.instance.labelFor(c);
  return label.isEmpty ? empty : label;
}

String _colorLabelForAd(Map<String, dynamic> ad) =>
    _colorLabelFromCode('${ad['color'] ?? ''}');

String _colorLabelForAdDetail(Map<String, dynamic> ad) =>
    _colorLabelFromCode('${ad['color'] ?? ''}', empty: '');

String _parseDesc(Map<String, dynamic> ad, String label) {
  final re = RegExp('^\\s*${RegExp.escape(label)}\\s*:\\s*(.+)\\s*\$', caseSensitive: false);
  for (final line in '${ad['description'] ?? ''}'.split('\n').take(20)) {
    final m = re.firstMatch(line);
    if (m != null) return m.group(1)!.trim();
  }
  return '—';
}

String _parseDescType(Map<String, dynamic> ad) {
  for (final label in [
    'Тип',
    'Вид',
    'Порода',
    'Инструмент',
    'Событие',
    'Вид растения',
    'Вид бизнеса',
    'Вид / порода',
    'Тип материала',
    'Тип товара',
    'Вид услуги',
    'Вид работ',
  ]) {
    final v = _parseDesc(ad, label);
    if (v != '—') return v;
  }
  return '—';
}

String _shortCity(Map<String, dynamic> ad) {
  final label = shortLocalityLabel('${ad['location'] ?? ''}');
  return label.isEmpty ? '—' : label;
}

List<CompareRow> getCompareRows(CompareProfile profile) {
  CompareRow price() => CompareRow(
        'Цена',
        (ad) => formatAdListingPrice(ad['price'], '${ad['currency'] ?? ''}'),
      );
  CompareRow city() => CompareRow('Город', _shortCity);

  switch (profile) {
    case CompareProfile.transport:
      return [
        price(),
        city(),
        CompareRow('Состояние', (ad) {
          final m = num.tryParse('${ad['mileage'] ?? ''}');
          if (m != null && m.isFinite && m > 0) return 'С пробегом';
          return 'Новый';
        }),
        CompareRow('Год', (ad) => '${ad['year'] ?? '—'}'),
        CompareRow('Пробег', (ad) {
          final m = num.tryParse('${ad['mileage'] ?? ''}');
          if (m != null && m.isFinite && m > 0) {
            return '${m.toStringAsFixed(0)} км';
          }
          return '—';
        }),
        CompareRow('КПП', (ad) {
          final t = '${ad['transmission'] ?? ''}';
          return _transLabels[t] ?? (t.isEmpty ? '—' : t);
        }),
        CompareRow('Привод', (_) => '—'),
        CompareRow('Растаможен', (_) => '—'),
        CompareRow('Объём', (ad) {
          final cap = '${ad['capacity'] ?? ''}'.trim();
          if (cap.isEmpty) return '—';
          if (RegExp(r'л|см|cc|куб', caseSensitive: false).hasMatch(cap)) return cap;
          return '—';
        }),
        CompareRow('Цвет', _colorLabelForAd),
        CompareRow('Топливо', (ad) {
          final f = '${ad['fuel_type'] ?? ''}';
          return _fuelLabels[f] ?? (f.isEmpty ? '—' : f);
        }),
        CompareRow('Кузов', (ad) {
          final body = resolvePassengerBodyType(ad);
          return body.isEmpty ? '—' : body;
        }),
      ];
    case CompareProfile.catalog:
      return [
        price(),
        city(),
        CompareRow('Состояние', (ad) => _parseDesc(ad, 'Состояние')),
        CompareRow('Тип', _parseDescType),
        CompareRow('Модель', (ad) {
          final m = '${ad['model'] ?? ''}'.trim();
          return m.isEmpty ? '—' : m;
        }),
      ];
    case CompareProfile.construction:
      return [
        price(),
        city(),
        CompareRow('Состояние', (ad) => _parseDesc(ad, 'Состояние')),
        CompareRow('Тип', (ad) {
          final t = _parseDesc(ad, 'Тип');
          if (t != '—') return t;
          return _parseDesc(ad, 'Тип материала');
        }),
        CompareRow('Марка / модель', (ad) {
          final m = '${ad['model'] ?? ''}'.trim();
          return m.isEmpty ? '—' : m;
        }),
      ];
    case CompareProfile.home:
      return [
        price(),
        city(),
        CompareRow('Состояние', (ad) => _parseDesc(ad, 'Состояние')),
        CompareRow('Тип', (ad) {
          final t = _parseDesc(ad, 'Тип');
          if (t != '—') return t;
          return _parseDesc(ad, 'Тип товара');
        }),
        CompareRow('Цвет', _colorLabelForAd),
        CompareRow('Материал', (ad) => _parseDesc(ad, 'Материал')),
      ];
    case CompareProfile.electronics:
      return [
        price(),
        city(),
        CompareRow('Состояние', (ad) => _parseDesc(ad, 'Состояние')),
        CompareRow('Тип', (ad) => _parseDesc(ad, 'Тип')),
        CompareRow('Модель', (ad) {
          final m = '${ad['model'] ?? ''}'.trim();
          return m.isEmpty ? '—' : m;
        }),
        CompareRow('Цвет', _colorLabelForAd),
      ];
    case CompareProfile.services:
    case CompareProfile.work:
      return [
        price(),
        city(),
        CompareRow('Вид услуги', (ad) {
          final v = _parseDesc(ad, 'Вид услуги');
          if (v != '—') return v;
          final w = _parseDesc(ad, 'Вид работ');
          if (w != '—') return w;
          return _parseDesc(ad, 'Тип');
        }),
        CompareRow('Опыт', (ad) {
          final v = _parseDesc(ad, 'Опыт');
          if (v != '—') return v;
          return _parseDesc(ad, 'Стаж вождения');
        }),
        CompareRow('Регион', (ad) {
          final v = _parseDesc(ad, 'Регион');
          if (v != '—') return v;
          return _parseDesc(ad, 'Регион / зона');
        }),
      ];
    case CompareProfile.children:
      return [
        price(),
        city(),
        CompareRow('Состояние', (ad) => _parseDesc(ad, 'Состояние')),
        CompareRow('Тип', (ad) => _parseDesc(ad, 'Тип')),
      ];
    case CompareProfile.clothing:
      return [
        price(),
        city(),
        CompareRow('Состояние', (ad) => _parseDesc(ad, 'Состояние')),
        CompareRow('Размер', (ad) => _parseDesc(ad, 'Размер')),
        CompareRow('Тип', (ad) => _parseDesc(ad, 'Тип')),
      ];
    case CompareProfile.realEstate:
      return [
        price(),
        city(),
        CompareRow('Этаж', (_) => '—'),
        CompareRow('Площадь', (ad) {
          final cap = '${ad['capacity'] ?? ''}'.trim();
          if (cap.isEmpty || !RegExp(r'\d').hasMatch(cap)) return '—';
          return cap.contains('м') ? cap : '$cap м²';
        }),
        CompareRow('Комнат', (ad) {
          final m = '${ad['model'] ?? ''}'.trim();
          return m.isEmpty ? '—' : m;
        }),
        CompareRow('Ремонт', (_) => '—'),
        CompareRow('Санузел', (_) => '—'),
        CompareRow('Застройка', (_) => '—'),
        CompareRow('Отопление', (_) => '—'),
        CompareRow('Животные', (_) => '—'),
        CompareRow('Предоплата', (_) => '—'),
        CompareRow('Помещение', (ad) => '${ad['subcategory'] ?? '—'}'),
        CompareRow('Объект', (ad) => '${ad['brand'] ?? '—'}'),
        CompareRow('Дом', (_) => '—'),
      ];
    case CompareProfile.generic:
      return [
        price(),
        city(),
        CompareRow('Состояние', (ad) => _parseDesc(ad, 'Состояние')),
        CompareRow('Тип', _parseDescType),
        CompareRow('Модель', (ad) {
          final m = '${ad['model'] ?? ''}'.trim();
          return m.isEmpty ? '—' : m;
        }),
      ];
  }
}

bool _isEmptySpecValue(String value) {
  final s = value.trim();
  return s.isEmpty || s == '—' || s == '-' || s == '–';
}

List<CompareRow> _passengerCarDetailRows() {
  return [
    CompareRow('Состояние', (ad) {
      final m = num.tryParse('${ad['mileage'] ?? ''}');
      if (m != null && m.isFinite && m > 0) return 'С пробегом';
      return 'Новый';
    }),
    CompareRow('Год', (ad) => '${ad['year'] ?? '—'}'),
    CompareRow('Пробег', (ad) {
      final m = num.tryParse('${ad['mileage'] ?? ''}');
      if (m != null && m.isFinite && m > 0) return '${m.toStringAsFixed(0)} км';
      return '—';
    }),
    CompareRow('КПП', (ad) {
      final t = '${ad['transmission'] ?? ''}';
      return _transLabels[t] ?? (t.isEmpty ? '—' : t);
    }),
    CompareRow('Цвет', _colorLabelForAdDetail),
    CompareRow('Топливо', (ad) {
      final f = '${ad['fuel_type'] ?? ''}';
      return _fuelLabels[f] ?? (f.isEmpty ? '—' : f);
    }),
    CompareRow('Кузов', (ad) {
      final body = resolvePassengerBodyType(ad);
      return body.isEmpty ? '—' : body;
    }),
  ];
}

String _parseVehicleTypeFromDescription(String? description) {
  for (final line in (description ?? '').split('\n').take(12)) {
    final m = RegExp(r'^\s*Тип\s*:\s*(.+)\s*$', caseSensitive: false).firstMatch(line);
    if (m != null) return m.group(1)!.trim();
  }
  return '';
}

Map<String, dynamic> _enrichAdForSpecs(Map<String, dynamic> ad) {
  final t = _parseVehicleTypeFromDescription('${ad['description'] ?? ''}');
  if (t.isEmpty) return ad;
  return {...ad, 'vehicle_type': t};
}

List<CompareRow> _commercialVehicleDetailRows() {
  return [
    CompareRow('Год выпуска', (ad) => '${ad['year'] ?? ''}'.trim()),
    CompareRow('Тип', (ad) => '${ad['vehicle_type'] ?? ''}'.trim()),
    CompareRow('Марка', (ad) => '${ad['brand'] ?? ''}'.trim()),
    CompareRow('Модель', (ad) => '${ad['model'] ?? ''}'.trim()),
    CompareRow('Цвет', _colorLabelForAdDetail),
    CompareRow('Пробег', (ad) {
      final m = int.tryParse('${ad['mileage'] ?? ''}');
      if (m == null || m <= 0) return '';
      return '$m км';
    }),
    CompareRow('Топливо', (ad) {
      final f = '${ad['fuel_type'] ?? ''}';
      return _fuelLabels[f] ?? (f.isEmpty ? '' : f);
    }),
    CompareRow('КПП', (ad) {
      final t = '${ad['transmission'] ?? ''}';
      return _transLabels[t] ?? (t.isEmpty ? '' : t);
    }),
    CompareRow('Грузоподъёмность', (ad) => '${ad['capacity'] ?? ''}'.trim()),
  ];
}

String _parseSpecLine(Map<String, dynamic> ad, String label) {
  final re = RegExp('^\\s*${RegExp.escape(label)}\\s*:\\s*(.+)\\s*\$', caseSensitive: false);
  for (final line in '${ad['description'] ?? ''}'.split('\n').take(16)) {
    final m = re.firstMatch(line);
    if (m != null) return m.group(1)!.trim();
  }
  return '';
}

List<CompareRow> _phoneDetailRows() {
  return [
    CompareRow('Состояние', (ad) => _parseSpecLine(ad, 'Состояние')),
    CompareRow('Память', (ad) {
      final cap = '${ad['capacity'] ?? ''}'.trim();
      return cap.isNotEmpty ? cap : _parseSpecLine(ad, 'Память');
    }),
    CompareRow('Модель', (ad) => '${ad['model'] ?? ''}'.trim()),
    CompareRow('RAM', (ad) => _parseSpecLine(ad, 'RAM')),
    CompareRow('Цвет', _colorLabelForAdDetail),
  ];
}

List<CompareRow> _laptopDetailRows() => _phoneDetailRows();

List<CompareRow> _electronicsConditionDetailRows() {
  return [
    CompareRow('Состояние', (ad) => _parseSpecLine(ad, 'Состояние')),
    CompareRow('Тип', (ad) => _parseSpecLine(ad, 'Тип')),
    CompareRow('Модель', (ad) => '${ad['model'] ?? ''}'.trim()),
    CompareRow('Цвет', _colorLabelForAdDetail),
  ];
}

List<CompareRow> _servicesDetailRows(String cat, String sub) {
  const labels = [
    'Вид услуги',
    'Регион / зона',
    'Опыт / стаж',
    'Срок выполнения',
    'Языки',
    'Регион',
    'Регион выезда',
    'Маршрут / зона',
    'Район / город',
    'Вид работ',
    'Стаж вождения',
  ];
  return [
    for (final label in labels)
      CompareRow(label, (ad) => _parseSpecLine(ad, label)),
  ];
}

List<CompareRow> _constructionDetailRows() {
  const labels = ['Состояние', 'Тип материала', 'Тип', 'Объём / количество', 'Марка / модель'];
  return [for (final label in labels) CompareRow(label, (ad) => _parseSpecLine(ad, label))];
}

List<CompareRow> _catalogDetailRows() {
  const labels = [
    'Состояние',
    'Порода',
    'Возраст',
    'Пол',
    'Тип',
    'Вид растения',
    'Тип товара',
    'Тип оборудования',
    'Вид бизнеса',
    'Инструмент',
    'Марка / модель',
    'Модель',
    'Размер',
    'Доход / оборот',
    'Событие',
    'Дата',
    'Вид / порода',
  ];
  return [for (final label in labels) CompareRow(label, (ad) => _parseSpecLine(ad, label))];
}

List<CompareRow> _homeDetailRows() {
  return [
    CompareRow('Состояние', (ad) => _parseSpecLine(ad, 'Состояние')),
    CompareRow('Тип товара', (ad) => _parseSpecLine(ad, 'Тип товара')),
    CompareRow('Тип', (ad) => _parseSpecLine(ad, 'Тип')),
    CompareRow('Цвет', (ad) {
      final fromField = _colorLabelForAdDetail(ad);
      if (fromField.isNotEmpty) return fromField;
      return _parseSpecLine(ad, 'Цвет');
    }),
    CompareRow('Материал', (ad) => _parseSpecLine(ad, 'Материал')),
  ];
}

List<CompareRow> _childrenDetailRows() {
  return [
    CompareRow('Состояние', (ad) => _parseSpecLine(ad, 'Состояние')),
    CompareRow('Тип', (ad) {
      final t = _parseSpecLine(ad, 'Тип');
      return t.isNotEmpty ? t : _parseSpecLine(ad, 'Игрушки');
    }),
    CompareRow('Цвет', _colorLabelForAdDetail),
  ];
}

List<CompareRow> _clothingAccessoryDetailRows() {
  return [
    CompareRow('Состояние', (ad) => _parseSpecLine(ad, 'Состояние')),
    CompareRow('Тип', (ad) => _parseSpecLine(ad, 'Тип')),
    CompareRow('Модель / бренд', (ad) => '${ad['model'] ?? ''}'.trim()),
    CompareRow('Цвет', _colorLabelForAdDetail),
  ];
}

List<CompareRow> _clothingDetailRows() {
  return [
    CompareRow('Состояние', (ad) => _parseSpecLine(ad, 'Состояние')),
    CompareRow('Размер', (ad) => _parseSpecLine(ad, 'Размер')),
    CompareRow('Тип', (ad) => _parseSpecLine(ad, 'Тип')),
    CompareRow('Модель / бренд', (ad) {
      final m = '${ad['model'] ?? ''}'.trim();
      final size = _parseSpecLine(ad, 'Размер');
      if (m.isEmpty || m == size) return '';
      return m;
    }),
    CompareRow('Цвет', _colorLabelForAdDetail),
  ];
}

List<CompareRow> _electronicsSimpleDetailRows() {
  return [
    CompareRow('Модель', (ad) => '${ad['model'] ?? ''}'.trim()),
    CompareRow('Память', (ad) {
      final cap = '${ad['capacity'] ?? ''}'.trim();
      return cap.isEmpty ? '' : cap;
    }),
    CompareRow('Цвет', _colorLabelForAdDetail),
  ];
}

List<CompareRow> _apartmentDetailRows() {
  return [
    CompareRow('Площадь', (ad) {
      final m = int.tryParse('${ad['mileage'] ?? ''}');
      if (m != null && m > 0) return '$m м²';
      final cap = '${ad['capacity'] ?? ''}'.trim();
      if (cap.isEmpty) return '';
      return cap.contains('м') ? cap : '$cap м²';
    }),
    CompareRow('Этаж', (ad) {
      final y = int.tryParse('${ad['year'] ?? ''}');
      if (y == null || y <= 0 || y > 60) return '';
      return '$y';
    }),
    CompareRow('Комнат', (ad) {
      final r = '${ad['model'] ?? ''}'.trim();
      return r.isEmpty || r == '—' ? '' : r;
    }),
  ];
}

List<CompareRow> _motoVehicleDetailRows() {
  return [
    CompareRow('Год выпуска', (ad) => '${ad['year'] ?? ''}'.trim()),
    CompareRow('Цвет', _colorLabelForAdDetail),
    CompareRow('Пробег', (ad) {
      final m = int.tryParse('${ad['mileage'] ?? ''}');
      if (m == null || m <= 0) return '';
      return '$m км';
    }),
    CompareRow('Топливо', (ad) {
      final f = '${ad['fuel_type'] ?? ''}';
      return _fuelLabels[f] ?? (f.isEmpty ? '' : f);
    }),
    CompareRow('КПП', (ad) {
      final t = '${ad['transmission'] ?? ''}';
      return _transLabels[t] ?? (t.isEmpty ? '' : t);
    }),
    CompareRow('Объём', (ad) => '${ad['capacity'] ?? ''}'.trim()),
  ];
}

/// Строки блока «Характеристика» на странице объявления (без цены и города).
List<({String label, String value})> getAdDetailSpecs(Map<String, dynamic> ad) {
  if (isRealEstatePriceOnlyContext(
    '${ad['category_slug'] ?? ''}',
    '${ad['subcategory_slug'] ?? ''}',
  )) {
    return const [];
  }
  final cat = '${ad['category_slug'] ?? ''}';
  final sub = '${ad['subcategory_slug'] ?? ''}';
  final enriched = _enrichAdForSpecs(ad);
  final List<CompareRow> rows;
  if (isApartmentListingContext(cat, sub)) {
    rows = _apartmentDetailRows();
  } else if (isPhoneListingContext(cat, sub)) {
    rows = _phoneDetailRows();
  } else if (isLaptopListingContext(cat, sub)) {
    rows = _laptopDetailRows();
  } else if (isElectronicsAdContext(cat, sub)) {
    if (isPhoneListingContext(cat, sub)) {
      rows = _phoneDetailRows();
    } else if (isLaptopListingContext(cat, sub)) {
      rows = _laptopDetailRows();
    } else if (isElectronicsConditionBoardContext(cat, sub)) {
      rows = _electronicsConditionDetailRows();
    } else if (isElectronicsPriceOnlyContext(cat, sub)) {
      rows = _electronicsSimpleDetailRows();
    } else {
      rows = _electronicsConditionDetailRows();
    }
  } else if (isServicesPriceOnlyContext(cat, sub)) {
    rows = _servicesDetailRows(cat, sub);
  } else if (isConstructionAdContext(cat, sub)) {
    rows = _constructionDetailRows();
  } else if (isCatalogAdContext(cat, sub)) {
    rows = _catalogDetailRows();
  } else if (isHomeAdContext(cat, sub)) {
    rows = _homeDetailRows();
  } else if (isChildrenBoardContext(cat, sub)) {
    rows = _childrenDetailRows();
  } else if (isClothingAccessoryBoardContext(cat, sub)) {
    rows = _clothingAccessoryDetailRows();
  } else if (isClothingBoardContext(cat, sub)) {
    rows = _clothingDetailRows();
  } else if (isPassengerCarContext(cat, sub)) {
    rows = _passengerCarDetailRows();
  } else if (isCommercialTransportContext(cat, sub)) {
    rows = _commercialVehicleDetailRows();
  } else if (isMotoTransportContext(cat, sub)) {
    rows = _motoVehicleDetailRows();
  } else {
    rows = getCompareRows(inferCompareProfile(cat, sub))
        .where((row) => row.label != 'Цена' && row.label != 'Город')
        .toList();
  }

  return rows
      .map((row) => (label: row.label, value: row.get(enriched)))
      .where((row) => !_isEmptySpecValue(row.value))
      .toList();
}
