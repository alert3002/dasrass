import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сравнение по категориям: то 4 объявления дар ҳар категория.
class CompareStore extends ChangeNotifier {
  CompareStore._();
  static final instance = CompareStore._();

  static const _keyV2 = 'dastrass_compare_by_category';
  static const _keyLegacy = 'dastrass_compare_ids';
  static const maxItems = 4;

  Map<String, List<int>> _byCategory = {};

  int get count => _byCategory.values.fold<int>(0, (s, list) => s + list.length);

  List<int> idsFor(String categorySlug) {
    final slug = _normSlug(categorySlug);
    return List.unmodifiable(_byCategory[slug] ?? const []);
  }

  /// Ҳамаи ID дар ҳамаи категорияҳо (барои бейдж).
  List<int> get ids {
    final all = <int>[];
    for (final list in _byCategory.values) {
      all.addAll(list);
    }
    return all;
  }

  String _normSlug(String slug) {
    final s = slug.trim().toLowerCase();
    return s.isEmpty ? 'other' : s;
  }

  bool _hydrated = false;

  Future<void> hydrate({bool force = false}) async {
    if (_hydrated && !force) return;
    final p = await SharedPreferences.getInstance();
    Map<String, List<int>> next = {};
    final rawV2 = p.getString(_keyV2);
    if (rawV2 != null && rawV2.isNotEmpty) {
      next = _parseMap(rawV2);
    } else {
      final rawLegacy = p.getString(_keyLegacy);
      if (rawLegacy != null && rawLegacy.isNotEmpty) {
        final legacy = _parseList(rawLegacy);
        if (legacy.isNotEmpty) {
          next = {'other': legacy};
          await p.setString(_keyV2, jsonEncode(next));
          await p.remove(_keyLegacy);
        }
      }
    }
    _hydrated = true;
    if (_mapsEqual(next, _byCategory)) return;
    _byCategory = next;
    notifyListeners();
  }

  bool _mapsEqual(Map<String, List<int>> a, Map<String, List<int>> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final other = b[e.key];
      if (other == null || other.length != e.value.length) return false;
      for (var i = 0; i < e.value.length; i++) {
        if (e.value[i] != other[i]) return false;
      }
    }
    return true;
  }

  Map<String, List<int>> _parseMap(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      final out = <String, List<int>>{};
      data.forEach((key, value) {
        if (value is List) {
          out[_normSlug('$key')] = value
              .map((e) => int.tryParse('$e') ?? 0)
              .where((id) => id > 0)
              .take(maxItems)
              .toList();
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  List<int> _parseList(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .map((e) => int.tryParse('$e') ?? 0)
          .where((id) => id > 0)
          .take(maxItems)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyV2, jsonEncode(_byCategory));
    notifyListeners();
  }

  Future<void> setIdsFor(String categorySlug, List<int> next) async {
    final slug = _normSlug(categorySlug);
    _byCategory[slug] = next.where((id) => id > 0).take(maxItems).toList();
    await _save();
  }

  Future<void> clearAll() async {
    _byCategory = {};
    await _save();
  }

  String? categorySlugForId(int id) {
    for (final e in _byCategory.entries) {
      if (e.value.contains(id)) return e.key;
    }
    return null;
  }

  Future<bool> toggle(int id, {required String categorySlug}) async {
    if (id <= 0) return false;
    final slug = _normSlug(categorySlug);
    var ids = List<int>.from(_byCategory[slug] ?? const []);
    if (ids.contains(id)) {
      ids.remove(id);
      _byCategory[slug] = ids;
      await _save();
      return false;
    }
    if (ids.length >= maxItems) return false;
    ids.add(id);
    _byCategory[slug] = ids;
    await _save();
    return true;
  }
}
