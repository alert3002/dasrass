import 'board_filter_config.dart';
import 'passenger_car.dart';
import 'transport_profiles.dart';

String _norm(String? s) => (s ?? '').trim().toLowerCase();

bool _looksLikeSlug(String? value) {
  final s = _norm(value);
  return s.isNotEmpty && RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(s);
}

bool _meaningfulBrand(Map<String, dynamic> ad) {
  final brand = '${ad['brand'] ?? ''}'.trim();
  final title = '${ad['title'] ?? ''}'.trim();
  if (brand.isEmpty || brand.length > 48) return false;
  if (title.isNotEmpty && brand.toLowerCase() == title.toLowerCase()) return false;
  return true;
}

String _transportBranch(Map<String, dynamic> ad) {
  final cat = _norm('${ad['category_slug'] ?? ad['category']}');
  if (!isTransportCategory(cat)) return 'other';
  final sub = _norm('${ad['subcategory_slug'] ?? ad['subcategory']}');
  final path = (ad['subcategory_path_slugs'] as List?)
          ?.map((e) => _norm('$e'))
          .toList() ??
      [];
  if (isMotoTransportContext(cat, sub, path)) return 'moto';
  if (isCommercialTransportContext(cat, sub, path)) return 'commercial';
  if (isPassengerCarContext(cat, sub, path)) return 'passenger';
  if (path.any((s) => s.contains('moto') || s.contains('mototehn')) ||
      sub.contains('moto') ||
      sub.contains('mototehn')) {
    return 'moto';
  }
  if (path.any((s) => s.contains('legkovoy')) || sub.contains('legkovoy')) {
    return 'passenger';
  }
  return 'transport_unknown';
}

bool _branchesConflict(Map<String, dynamic> source, Map<String, dynamic> candidate) {
  final srcB = _transportBranch(source);
  final candB = _transportBranch(candidate);
  if (srcB == 'other' || candB == 'other') return false;
  if (srcB == 'transport_unknown' || candB == 'transport_unknown') return false;
  return srcB != candB;
}

List<String> _subSlugsForQuery(Map<String, dynamic> ad) {
  final path = ad['subcategory_path_slugs'];
  final out = <String>[];
  final seen = <String>{};
  void add(String s) {
    final n = _norm(s);
    if (n.isEmpty || seen.contains(n)) return;
    seen.add(n);
    out.add(n);
  }
  if (path is List && path.isNotEmpty) {
    for (var i = path.length - 1; i >= 0; i--) {
      add('${path[i]}');
    }
  } else {
    add('${ad['subcategory_slug'] ?? ad['subcategory']}');
  }
  return out;
}

List<Map<String, String>> buildRelatedAdsQueryLevels(Map<String, dynamic> ad) {
  final category = _norm('${ad['category_slug'] ?? ad['category']}');
  if (category.isEmpty) return [];

  final subSlugs = _subSlugsForQuery(ad);
  final brand = '${ad['brand'] ?? ''}'.trim();
  final model = '${ad['model'] ?? ''}'.trim();
  final transport = isTransportCategory(category);
  final meaningfulBrand = _meaningfulBrand(ad);
  final levels = <Map<String, String>>[];
  final seen = <String>{};

  void push(Map<String, String> p) {
    final key = p.entries.map((e) => '${e.key}=${e.value}').join('&');
    if (seen.add(key)) levels.add(p);
  }

  for (final subcategory in subSlugs) {
    if (meaningfulBrand && model.isNotEmpty) {
      push({
        'category': category,
        'subcategory': subcategory,
        'brand': brand,
        'model': model,
        'limit': '20',
      });
    }
    if (meaningfulBrand) {
      push({
        'category': category,
        'subcategory': subcategory,
        'brand': brand,
        'limit': '20',
      });
    }
    if (model.isNotEmpty) {
      push({
        'category': category,
        'subcategory': subcategory,
        'model': model,
        'limit': '20',
      });
    }
    push({'category': category, 'subcategory': subcategory, 'limit': '20'});
  }

  if (subSlugs.isEmpty && meaningfulBrand) {
    if (model.isNotEmpty) {
      push({'category': category, 'brand': brand, 'model': model, 'limit': '20'});
    }
    push({'category': category, 'brand': brand, 'limit': '20'});
  }

  if (!transport && subSlugs.isEmpty) {
    push({'category': category, 'limit': '20'});
  }

  return levels;
}

bool isSimilarAdCandidate(
  Map<String, dynamic> source,
  Map<String, dynamic> candidate, {
  bool strictBrand = true,
}) {
  final srcId = int.tryParse('${source['id']}') ?? 0;
  final candId = int.tryParse('${candidate['id']}') ?? 0;
  if (candId <= 0 || candId == srcId) return false;

  final srcCat = _norm('${source['category_slug'] ?? source['category']}');
  final candCat = _norm('${candidate['category_slug'] ?? candidate['categorySlug'] ?? ''}');

  if (srcCat.isNotEmpty &&
      candCat.isNotEmpty &&
      _looksLikeSlug(srcCat) &&
      _looksLikeSlug(candCat) &&
      srcCat != candCat) {
    return false;
  }

  if (_branchesConflict(source, candidate)) return false;

  if (strictBrand && _meaningfulBrand(source)) {
    final brand = '${source['brand'] ?? ''}'.trim();
    final candBrand = '${candidate['brand'] ?? ''}'.trim();
    if (candBrand.isNotEmpty && candBrand.toLowerCase() != brand.toLowerCase()) {
      return false;
    }
  }

  return true;
}
