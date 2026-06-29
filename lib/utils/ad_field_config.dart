import 'catalog_profiles.dart';
import 'clothing_profiles.dart';
import 'color_catalog.dart';
import 'construction_profiles.dart';
import 'children_profiles.dart';
import 'electronics_profiles.dart';
import 'home_profiles.dart';
import 'passenger_car.dart';
import 'real_estate_profiles.dart';
import 'services_profiles.dart';
import 'transport_profiles.dart';

enum AdFieldSection { regular, characteristics }

enum AdFieldType { text, number, select }

class AdDynamicField {
  const AdDynamicField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    this.options = const [],
    this.placeholder = '',
    this.section = AdFieldSection.regular,
    this.hidden = false,
  });

  final String key;
  final String label;
  final AdFieldType type;
  final bool required;
  final List<String> options;
  final String placeholder;
  final AdFieldSection section;
  final bool hidden;

  factory AdDynamicField.text(
    String key,
    String label,
    bool required, {
    String placeholder = '',
    AdFieldSection section = AdFieldSection.regular,
    bool hidden = false,
  }) =>
      AdDynamicField(
        key: key,
        label: label,
        type: AdFieldType.text,
        required: required,
        placeholder: placeholder,
        section: section,
        hidden: hidden,
      );

  factory AdDynamicField.number(
    String key,
    String label,
    bool required, {
    String placeholder = '',
    AdFieldSection section = AdFieldSection.regular,
    bool hidden = false,
  }) =>
      AdDynamicField(
        key: key,
        label: label,
        type: AdFieldType.number,
        required: required,
        placeholder: placeholder,
        section: section,
        hidden: hidden,
      );

  factory AdDynamicField.select(
    String key,
    String label,
    bool required,
    List<String> options, {
    String placeholder = '',
    AdFieldSection section = AdFieldSection.regular,
    bool hidden = false,
  }) =>
      AdDynamicField(
        key: key,
        label: label,
        type: AdFieldType.select,
        required: required,
        options: options,
        placeholder: placeholder,
        section: section,
        hidden: hidden,
      );

  AdDynamicField copyWith({bool? hidden, List<String>? options}) => AdDynamicField(
        key: key,
        label: label,
        type: type,
        required: required,
        options: options ?? this.options,
        placeholder: placeholder,
        section: section,
        hidden: hidden ?? this.hidden,
      );
}

List<String> adFieldYearOptions() =>
    List.generate(31, (i) => '${DateTime.now().year - i}');

const _fuelOptions = ['Дизель', 'Бензин', 'Газ', 'Электро', 'Гибрид'];
const _transOptions = ['Механика', 'Автомат', 'Робот'];
const _passengerRedundant = {'type', 'brand', 'model'};
const _motoRedundant = {'type', 'brand', 'model'};

List<AdDynamicField> _transportCommonFields(List<String> colorOptions) => [
      AdDynamicField.select('year', 'Год выпуска', true, adFieldYearOptions()),
      AdDynamicField.text('type', 'Тип', true, placeholder: 'Например: бортовой, рефрижератор'),
      AdDynamicField.text('brand', 'Марка', true, placeholder: 'Mercedes-Benz, MAN, Volvo'),
      AdDynamicField.text('model', 'Модель', true, placeholder: 'Actros, TGX, FH'),
      AdDynamicField.select('color', 'Цвет', true, colorOptions),
      AdDynamicField.number('mileage', 'Пробег, км', true, placeholder: '250000'),
      AdDynamicField.select('fuel', 'Топливо', true, _fuelOptions),
      AdDynamicField.select('transmission', 'КПП', true, _transOptions),
    ];

List<AdDynamicField> _passengerCarFields(List<String> colorOptions) => [
      AdDynamicField.select('year', 'Год выпуска', true, adFieldYearOptions()),
      AdDynamicField.select('color', 'Цвет', true, colorOptions),
      AdDynamicField.number('mileage', 'Пробег, км', true, placeholder: '250000'),
      AdDynamicField.select('fuel', 'Топливо', true, _fuelOptions),
      AdDynamicField.select('transmission', 'КПП', true, _transOptions),
      AdDynamicField.text('capacity', 'Объём двигателя', true, placeholder: '2.0 л'),
    ];

List<AdDynamicField> _motoFields(List<String> colorOptions) => [
      AdDynamicField.select('year', 'Год выпуска', true, adFieldYearOptions()),
      AdDynamicField.select('color', 'Цвет', true, colorOptions),
      AdDynamicField.number('mileage', 'Пробег, км', true, placeholder: '250000'),
      AdDynamicField.select('fuel', 'Топливо', true, _fuelOptions),
      AdDynamicField.select('transmission', 'КПП', true, _transOptions),
      AdDynamicField.text('capacity', 'Объём двигателя', true, placeholder: '600 см³'),
    ];

Map<String, List<AdDynamicField>> _categoryFields(List<String> colors) => {
      'transport': [
        ..._transportCommonFields(colors),
        AdDynamicField.text('capacity', 'Грузоподъёмность', false, placeholder: '20 т'),
      ],
      'nedvizhimsot': [
        AdDynamicField.select('year', 'Год постройки (если есть)', false, adFieldYearOptions()),
        AdDynamicField.number('area', 'Площадь, м²', false, placeholder: '65'),
      ],
      'elektronika': [
        AdDynamicField.text('model', 'Модель', false, placeholder: 'iPhone 15, Samsung A54…'),
        AdDynamicField.text('memory', 'Память', false, placeholder: '128 ГБ'),
        AdDynamicField.text('ram', 'RAM', false, placeholder: '8 ГБ'),
        AdDynamicField.select('color', 'Цвет', false, colors),
        AdDynamicField.select('condition', 'Состояние', false, const ['Новый', 'Б/у']),
      ],
      'rabota': [
        AdDynamicField.text('experience', 'Стаж', false, placeholder: 'от 1 года'),
        AdDynamicField.text('salary', 'Зарплата', false, placeholder: '3000 сомони'),
        AdDynamicField.text('services', 'Услуги', false, placeholder: 'Полный день, удалённо'),
        AdDynamicField.text('type', 'Тип', false, placeholder: 'Вакансия, резюме'),
      ],
    };

Map<String, List<AdDynamicField>> _subcategoryFields(List<String> colors) => {
      'telefony': [
        AdDynamicField.text('model', 'Модель', false, placeholder: 'TECNO Spark, iPhone…'),
        AdDynamicField.text('memory', 'Память', false, placeholder: '256 ГБ'),
        AdDynamicField.text('ram', 'RAM', false, placeholder: '8 ГБ'),
        AdDynamicField.select('color', 'Цвет', false, colors),
      ],
      'avtobusy': [AdDynamicField.number('seats', 'Количество мест', true, placeholder: '45')],
      'mikroavtobusy': [AdDynamicField.number('seats', 'Количество мест', true, placeholder: '18')],
      'polupricepy': [AdDynamicField.number('axles', 'Количество осей', true, placeholder: '3')],
      'pricepy': [AdDynamicField.number('axles', 'Количество осей', true, placeholder: '2')],
      'tsisterny': [
        AdDynamicField.text('tank_volume', 'Объём цистерны', true, placeholder: '30 000 л'),
      ],
      'mototehnika': [
        AdDynamicField.text('engine_volume', 'Объём двигателя', true, placeholder: '600 см³'),
      ],
      'vodnyy-transport': [AdDynamicField.text('length', 'Длина', true, placeholder: '8 м')],
      'shiny-i-diski': [AdDynamicField.text('size', 'Размер', true, placeholder: '315/80 R22.5')],
    };

List<AdDynamicField> _commercialFields(List<String> colors) => [
      ..._transportCommonFields(colors).map(
        (f) => AdDynamicField(
          key: f.key,
          label: f.label,
          type: f.type,
          required: f.required,
          options: f.options,
          placeholder: f.placeholder,
          section: AdFieldSection.characteristics,
        ),
      ),
      AdDynamicField.text('capacity', 'Грузоподъёмность', false, placeholder: '20 т',
          section: AdFieldSection.characteristics),
    ];

List<AdDynamicField> applyColorOptions(List<AdDynamicField> fields, List<String> colorLabels) {
  final opts = colorLabels.isNotEmpty ? colorLabels : defaultColorOptionLabels();
  return fields
      .map(
        (f) => f.key == 'color' && f.type == AdFieldType.select
            ? f.copyWith(options: List<String>.from(opts))
            : f,
      )
      .toList();
}

List<AdDynamicField> getDynamicFields(
  String categorySlug,
  String subcategorySlug, {
  List<String> subcategoryPath = const [],
  String subcategoryFullPath = '',
  List<String> colorOptions = const [],
}) {
  final catFields = _categoryFields(colorOptions)[categorySlug] ?? const <AdDynamicField>[];
  final subFields = _subcategoryFields(colorOptions)[subcategorySlug] ?? const <AdDynamicField>[];
  final merged = <AdDynamicField>[...catFields];
  for (final f in subFields) {
    if (!merged.any((m) => m.key == f.key)) merged.add(f);
  }

  final path = subcategoryPath;
  final passenger = isPassengerCarContext(categorySlug, subcategorySlug, path) ||
      subcategoryFullPath.toLowerCase().contains('легков') ||
      subcategoryFullPath.toLowerCase().contains('legkovoy');
  final moto = isMotoTransportContext(categorySlug, subcategorySlug, path);
  final commercial = isCommercialTransportContext(categorySlug, subcategorySlug, path);
  final partsOnly = isPartsAccessoriesContext(categorySlug, subcategorySlug, path);
  final simpleTransport = isSimpleTransportListingContext(categorySlug, subcategorySlug, path);
  final realEstatePriceOnly = isRealEstatePriceOnlyContext(categorySlug, subcategorySlug, path);
  final apartmentListing = isApartmentListingContext(categorySlug, subcategorySlug, path);
  final electronicsPriceOnly = isElectronicsPriceOnlyContext(categorySlug, subcategorySlug, path);
  final phoneListing = isPhoneListingContext(categorySlug, subcategorySlug, path);
  final laptopListing = isLaptopListingContext(categorySlug, subcategorySlug, path);
  final electronicsConditionBoard =
      isElectronicsConditionBoardContext(categorySlug, subcategorySlug, path);
  final clothingAccessoryBoard = isClothingAccessoryBoardContext(categorySlug, subcategorySlug, path);
  final clothingBoard = isClothingBoardContext(categorySlug, subcategorySlug, path);
  final childrenBoard = isChildrenBoardContext(categorySlug, subcategorySlug, path);
  final homeBoard = isHomeBoardContext(categorySlug, subcategorySlug, path);
  final constructionPriceOnly = isConstructionPriceOnlyContext(categorySlug, subcategorySlug, path);
  final servicesPriceOnly = isServicesPriceOnlyContext(categorySlug, subcategorySlug, path);
  final catalogPriceOnly = isCatalogPriceOnlyContext(categorySlug, subcategorySlug, path);

  if (commercial) return applyColorOptions(_commercialFields(colorOptions), colorOptions);
  if (apartmentListing) {
    return [
      AdDynamicField.number('area', 'Площадь, м²', true, placeholder: '65',
          section: AdFieldSection.characteristics),
      AdDynamicField.number('floor', 'Этаж', true, placeholder: '5', section: AdFieldSection.characteristics),
      AdDynamicField.select('rooms', 'Комнат', false, const ['1', '2', '3', '4', '5', '6+'],
          section: AdFieldSection.characteristics),
    ];
  }
  if (phoneListing) {
    return applyColorOptions([
      AdDynamicField.select('condition', 'Состояние', true, const ['Новый', 'Б/у'],
          section: AdFieldSection.characteristics),
      AdDynamicField.text('memory', 'Память', true, placeholder: '128 ГБ', section: AdFieldSection.characteristics),
      AdDynamicField.text('model', 'Модель', true, placeholder: 'iPhone 15, Galaxy A54…',
          section: AdFieldSection.characteristics),
      AdDynamicField.select('color', 'Цвет', true, colorOptions, section: AdFieldSection.characteristics),
    ], colorOptions);
  }
  if (childrenBoard) {
    return applyColorOptions([
      AdDynamicField.select('condition', 'Состояние', true, const ['Новый', 'Б/у'],
          section: AdFieldSection.characteristics),
      AdDynamicField.text('type', 'Тип', false, placeholder: 'Кукла, коляска…',
          section: AdFieldSection.characteristics),
      AdDynamicField.select('color', 'Цвет', false, colorOptions, section: AdFieldSection.characteristics),
    ], colorOptions);
  }
  if (homeBoard) return getHomeCharacteristicFields(categorySlug, subcategorySlug, path);
  if (constructionPriceOnly) {
    return getConstructionCharacteristicFields(categorySlug, subcategorySlug, path);
  }
  if (servicesPriceOnly) {
    return getServicesCharacteristicFields(categorySlug, subcategorySlug, path);
  }
  if (catalogPriceOnly) {
    return getCatalogCharacteristicFields(categorySlug, subcategorySlug, path);
  }
  if (clothingBoard || clothingAccessoryBoard || electronicsPriceOnly || laptopListing ||
      electronicsConditionBoard) {
    return applyColorOptions(merged.map((f) {
      return AdDynamicField(
        key: f.key,
        label: f.label,
        type: f.type,
        required: f.required,
        options: f.options,
        placeholder: f.placeholder,
        section: AdFieldSection.characteristics,
      );
    }).toList(), colorOptions);
  }
  if (partsOnly || simpleTransport || realEstatePriceOnly) return const [];

  if (passenger) {
    final pFields = _passengerCarFields(colorOptions);
    final engineCap = pFields.firstWhere((f) => f.key == 'capacity');
    final hiddenMerged = merged
        .map((f) {
          if (_passengerRedundant.contains(f.key)) return f.copyWith(hidden: true);
          if (f.key == 'capacity') return engineCap;
          return f;
        })
        .toList();
    final keys = hiddenMerged.map((f) => f.key).toSet();
    final extra = pFields.where((f) => !keys.contains(f.key));
    return applyColorOptions([...hiddenMerged, ...extra], colorOptions);
  }

  if (moto) {
    final mFields = _motoFields(colorOptions);
    final engineCap = mFields.firstWhere((f) => f.key == 'capacity');
    final hiddenMerged = merged
        .map((f) {
          if (_motoRedundant.contains(f.key)) return f.copyWith(hidden: true);
          if (f.key == 'capacity') return engineCap;
          return f;
        })
        .toList();
    final keys = hiddenMerged.map((f) => f.key).toSet();
    final extra = mFields.where((f) => !keys.contains(f.key));
    return applyColorOptions([...hiddenMerged, ...extra], colorOptions);
  }

  return applyColorOptions(merged, colorOptions);
}

bool showPassengerBodyTypeSelect({
  required bool isPassengerCar,
  required List<String> subcategoryPath,
  required int level2Count,
  required int level3Count,
  required String? leafSubcategory,
}) {
  if (!isPassengerCar) return false;
  if (subcategoryPath.length > 1 && level3Count > 0) return subcategoryPath.length > 2;
  if (subcategoryPath.isNotEmpty && level2Count > 0) return subcategoryPath.length > 1;
  return leafSubcategory != null && leafSubcategory.isNotEmpty;
}

String prependVehicleTypeToDescription(String description, String vehicleType) {
  final t = vehicleType.trim();
  final rest = stripVehicleTypeFromDescription(description);
  if (t.isEmpty) return rest;
  return rest.isEmpty ? 'Тип: $t' : 'Тип: $t\n\n$rest';
}

String stripVehicleTypeFromDescription(String description) {
  return description
      .split('\n')
      .where((line) => !RegExp(r'^\s*Тип\s*:', caseSensitive: false).hasMatch(line))
      .join('\n')
      .trim();
}

({String brand, String model})? passengerCarBrandModelFromPath(
  List<dynamic>? rootNodes,
  List<String> slugPath,
) {
  if (rootNodes == null || slugPath.isEmpty) return null;
  if (!isPassengerCarContext('transport', slugPath.last, slugPath)) return null;
  final labels = <String>[];
  var level = rootNodes;
  for (final slug in slugPath) {
    if (slug.isEmpty) break;
    Map<String, dynamic>? node;
    for (final raw in level) {
      final m = raw as Map<String, dynamic>;
      if ('${m['slug']}' == slug) {
        node = m;
        break;
      }
    }
    if (node == null) break;
    final name = '${node['name'] ?? ''}'.trim();
    if (name.isNotEmpty) labels.add(name);
    level = node['children'] as List<dynamic>? ?? const [];
  }
  if (labels.length < 2) return null;
  final rest = labels.sublist(1);
  if (rest.length == 1) return (brand: rest[0], model: '');
  return (brand: rest[0], model: rest.sublist(1).join(' '));
}

String prependBodyToDescription(String description, String bodyType) {
  final body = bodyType.trim();
  final rest = stripBodyTypeFromDescription(description);
  if (body.isEmpty) return rest;
  return rest.isEmpty ? 'Кузов: $body' : 'Кузов: $body\n\n$rest';
}

String stripBodyTypeFromDescription(String description) {
  return description
      .split('\n')
      .where((line) => !RegExp(r'^\s*Кузов\s*:', caseSensitive: false).hasMatch(line))
      .join('\n')
      .trim();
}

// --- Characteristic field sets (from adFieldConfig.js helpers) ---

const _char = AdFieldSection.characteristics;

String _normSlug(String? s) => (s ?? '').trim().toLowerCase();

String _resolveHomeSubSlug(String subcategorySlug, List<String> path) {
  final slugs = <String>{
    if (_normSlug(subcategorySlug).isNotEmpty) _normSlug(subcategorySlug),
    ...path.reversed.map(_normSlug).where((s) => s.isNotEmpty),
    'vse-dlya-doma',
  }.toList();
  return slugs.firstWhere((s) => s != 'vse-dlya-doma', orElse: () => _normSlug(subcategorySlug));
}

List<AdDynamicField> getHomeCharacteristicFields(
  String categorySlug,
  String subcategorySlug,
  List<String> path,
) {
  const colors = [
    'Белый', 'Чёрный', 'Серый', 'Коричневый', 'Бежевый', 'Синий', 'Зелёный', 'Красный', 'Другой',
  ];
  if (!isHomeCategory(categorySlug)) {
    return [
      AdDynamicField.select('condition', 'Состояние', true, const ['Новый', 'Б/у'], section: _char),
      AdDynamicField.text('type', 'Тип товара', true, placeholder: 'Диван, холодильник', section: _char),
      AdDynamicField.select('color', 'Цвет', false, colors, section: _char),
    ];
  }
  final g = _normSlug(_resolveHomeSubSlug(subcategorySlug, path));
  if (g == 'mebel' || g.startsWith('mebel-')) {
    return [
      AdDynamicField.select('condition', 'Состояние', true, const ['Новый', 'Б/у'], section: _char),
      AdDynamicField.text('type', 'Тип', true, placeholder: 'Диван, шкаф, стол…', section: _char),
      AdDynamicField.text('material', 'Материал', false, placeholder: 'Дерево, ЛДСП…', section: _char),
      AdDynamicField.select('color', 'Цвет', false, colors, section: _char),
    ];
  }
  return [
    AdDynamicField.select('condition', 'Состояние', true, const ['Новый', 'Б/у'], section: _char),
    AdDynamicField.text('type', 'Тип товара', true, placeholder: 'Диван, холодильник', section: _char),
    AdDynamicField.select('color', 'Цвет', false, colors, section: _char),
  ];
}

List<AdDynamicField> getConstructionCharacteristicFields(
  String categorySlug,
  String subcategorySlug,
  List<String> path,
) {
  if (!isConstructionCategory(categorySlug)) {
    return [
      AdDynamicField.select('condition', 'Состояние', true, const ['Новый', 'Б/у'], section: _char),
      AdDynamicField.text('type', 'Тип', true, placeholder: 'Цемент, кирпич', section: _char),
    ];
  }
  return [
    AdDynamicField.select('condition', 'Состояние', true, const ['Новый', 'Б/у'], section: _char),
    AdDynamicField.text('type', 'Тип', true, placeholder: 'Цемент, кирпич', section: _char),
  ];
}

List<AdDynamicField> getServicesCharacteristicFields(
  String categorySlug,
  String subcategorySlug,
  List<String> path,
) {
  return [
    AdDynamicField.text('type', 'Вид услуги', true, placeholder: 'Ремонт, доставка', section: _char),
    AdDynamicField.text('service_area', 'Регион / зона', false, placeholder: 'Душанбе…', section: _char),
    AdDynamicField.text('experience', 'Опыт / стаж', false, placeholder: 'от 3 лет', section: _char),
  ];
}

List<AdDynamicField> getCatalogCharacteristicFields(
  String categorySlug,
  String subcategorySlug,
  List<String> path,
) {
  return [
    AdDynamicField.select('condition', 'Состояние', true, const ['Новый', 'Б/у'], section: _char),
    AdDynamicField.text('type', 'Тип', true, placeholder: 'Грузовик, автобус', section: _char),
  ];
}

const homeSpecLabels = <String, String>{
  'condition': 'Состояние',
  'type': 'Тип товара',
  'color': 'Цвет',
  'material': 'Материал',
};

const serviceSpecLabels = <String, String>{
  'type': 'Вид услуги',
  'service_area': 'Регион / зона',
  'experience': 'Опыт / стаж',
  'deadline': 'Срок выполнения',
  'languages': 'Языки',
};
