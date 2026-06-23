import 'package:flutter/foundation.dart';

/// Повторный вход на таб Reels — новая случайная лента.
class ReelsFeedReload {
  ReelsFeedReload._();

  static final ReelsFeedReload instance = ReelsFeedReload._();

  final ValueNotifier<int> tick = ValueNotifier(0);

  void bump() {
    tick.value += 1;
  }
}
