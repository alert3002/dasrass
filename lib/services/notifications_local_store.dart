import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Мисли [frontend/src/utils/notificationsStore.js]: уведомления в памяти устройства.
class NotificationsLocalStore extends ChangeNotifier {
  NotificationsLocalStore._();
  static final instance = NotificationsLocalStore._();

  static const _key = 'dastrass_notifications_v1';
  static const _maxItems = 200;
  static const _ttlMs = 24 * 60 * 60 * 1000;

  List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) {
      _items = [];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _items = [];
        return;
      }
      final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final fresh = list.where(_isFresh).take(_maxItems).toList();
      _items = fresh;
      if (fresh.length != list.length) {
        await _persist();
      }
    } catch (_) {
      _items = [];
    }
  }

  bool _isFresh(Map<String, dynamic> item) {
    final created = item['created_at'];
    if (created is! String) return false;
    final ts = DateTime.tryParse(created)?.millisecondsSinceEpoch;
    if (ts == null || !ts.isFinite) return false;
    return DateTime.now().millisecondsSinceEpoch - ts <= _ttlMs;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_items));
    notifyListeners();
  }

  int unreadCount() => _items.where((n) => n['read'] != true).length;

  void addNotification(String message, {String type = 'success'}) {
    final text = message.trim();
    if (text.isEmpty) return;
    final tone = type == 'error' ? 'error' : 'success';
    final id = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
    final item = {
      'id': id,
      'message': text,
      'type': tone,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'read': false,
    };
    _items = [item, ..._items].take(_maxItems).toList();
    _persist();
  }

  Future<void> markAllRead() async {
    _items = _items
        .map((n) => Map<String, dynamic>.from(n)..['read'] = true)
        .toList();
    await _persist();
  }

  Future<void> clear() async {
    _items = [];
    await _persist();
  }
}
