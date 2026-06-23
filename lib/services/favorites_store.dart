import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Избранное барои корбари бе вуруд — ID-ҳо дар SharedPreferences.
class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();
  static final instance = FavoritesStore._();

  static const _key = 'dastrass_favorite_ids';

  List<int> _ids = [];

  int get count => _ids.length;

  List<int> get ids => List.unmodifiable(_ids);

  bool contains(int id) => id > 0 && _ids.contains(id);

  Future<void> hydrate() async {
    final p = await SharedPreferences.getInstance();
    _ids = _parse(p.getString(_key));
    notifyListeners();
  }

  List<int> _parse(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return [];
      return data
          .map((e) => int.tryParse('$e') ?? 0)
          .where((id) => id > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_ids));
    notifyListeners();
  }

  /// `true` — баъд аз toggle дар избранном аст.
  Future<bool> toggle(int id) async {
    if (id <= 0) return false;
    await hydrate();
    if (_ids.contains(id)) {
      _ids.remove(id);
      await _save();
      return false;
    }
    _ids.insert(0, id);
    await _save();
    return true;
  }

  Future<void> remove(int id) async {
    if (id <= 0) return;
    await hydrate();
    if (_ids.remove(id)) {
      await _save();
    }
  }
}
