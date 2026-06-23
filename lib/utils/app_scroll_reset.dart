import 'package:flutter/material.dart';

/// Сброс прокрутки при смене маршрута / таба.
class AppScrollReset {
  AppScrollReset._();

  static final AppScrollReset instance = AppScrollReset._();

  final Map<String, ScrollController> _controllers = {};
  String? _lastLocation;

  void register(String routeKey, ScrollController controller) {
    _controllers[routeKey] = controller;
  }

  void unregister(String routeKey, ScrollController controller) {
    final current = _controllers[routeKey];
    if (identical(current, controller)) {
      _controllers.remove(routeKey);
    }
  }

  void onLocationChanged(String location) {
    if (_lastLocation == location) return;
    _lastLocation = location;
    WidgetsBinding.instance.addPostFrameCallback((_) => resetForLocation(location));
  }

  void resetKey(String routeKey) {
    final controller = _controllers[routeKey];
    if (controller == null || !controller.hasClients) return;
    controller.jumpTo(0);
  }

  void resetForLocation(String location) {
    resetKey(location);
    final uri = Uri.tryParse(location);
    if (uri == null) return;
    resetKey(uri.path);
  }
}
