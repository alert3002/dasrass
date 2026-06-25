import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальный список заблокированных номеров (без зависимости от API).
class BlockedPhonesStore extends ChangeNotifier {
  BlockedPhonesStore._();
  static final BlockedPhonesStore instance = BlockedPhonesStore._();

  static const _prefsKey = 'blocked_phones_v1';

  final Set<String> _blocked = {};
  bool _loaded = false;

  Set<String> get phones => Set.unmodifiable(_blocked);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    _blocked
      ..clear()
      ..addAll(p.getStringList(_prefsKey) ?? const []);
    _loaded = true;
  }

  Future<void> replaceAll(Iterable<String> phones) async {
    await ensureLoaded();
    _blocked
      ..clear()
      ..addAll(phones.map(_norm).where((p) => p.isNotEmpty));
    await _persist();
    notifyListeners();
  }

  Future<void> add(String phone) async {
    final p = _norm(phone);
    if (p.isEmpty) return;
    await ensureLoaded();
    _blocked.add(p);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_prefsKey, _blocked.toList());
    _loaded = true;
  }

  String _norm(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  bool isPhoneBlocked(String? phone) {
    final p = _norm(phone ?? '');
    if (p.isEmpty) return false;
    if (_blocked.contains(p)) return true;
    if (p.length >= 9 && _blocked.contains(p.substring(p.length - 9))) return true;
    return false;
  }

  List<Map<String, dynamic>> filterAds(Iterable<dynamic> ads) {
    return ads
        .where((raw) {
          if (raw is! Map) return true;
          return !isPhoneBlocked('${raw['phone'] ?? ''}');
        })
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
