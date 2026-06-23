import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'dastrass_api.dart';
import 'notifications_local_store.dart';

/// Мисли [Layout.jsx]: `localUnread + serverUnread`, polling ҳар 10 с.
class NotificationUnreadHub extends ChangeNotifier {
  NotificationUnreadHub._();
  static final instance = NotificationUnreadHub._();

  int count = 0;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    AuthService.instance.addListener(_onAuthOrStore);
    NotificationsLocalStore.instance.addListener(_onAuthOrStore);
    refresh();
    Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }

  void _onAuthOrStore() {
    refresh();
  }

  Future<void> refresh() async {
    final local = NotificationsLocalStore.instance.unreadCount();
    if (!AuthService.instance.isAuthenticated) {
      count = local;
      notifyListeners();
      return;
    }
    try {
      final server = await DastrassApi.instance.notificationsUnreadCount();
      count = local + server;
    } catch (_) {
      count = local;
    }
    notifyListeners();
  }
}
