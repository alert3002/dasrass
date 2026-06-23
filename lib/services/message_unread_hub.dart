import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'dastrass_api.dart';

/// Polling ҳамон unread чат — барои нишона дар footer.
class MessageUnreadHub extends ChangeNotifier {
  MessageUnreadHub._();
  static final instance = MessageUnreadHub._();

  int count = 0;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    AuthService.instance.addListener(_onAuth);
    refresh();
    Timer.periodic(const Duration(seconds: 12), (_) => refresh());
  }

  void _onAuth() {
    refresh();
  }

  Future<void> refresh() async {
    if (!AuthService.instance.isAuthenticated) {
      count = 0;
      notifyListeners();
      return;
    }
    try {
      count = await DastrassApi.instance.messagesUnreadCount();
    } catch (_) {
      // нигоҳ доштани қимати қаблӣ
    }
    notifyListeners();
  }
}
