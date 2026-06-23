import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/app_scroll_reset.dart';
import '../utils/reels_feed_reload.dart';

/// Табҳои асосии [DastrassMobileTabBar]: Главная, Reels, Добавить, Избранное, Профиль.
const kMainTabPaths = ['/home', '/reels', '/add', '/favorites', '/profile'];

/// Индекси таби интихобшуда; барои саҳифаҳои берунӣ (масалан `/ads/1`) `null`.
int? mainTabIndexForLocation(String location) {
  final path = Uri.parse(location).path;
  if (path == '/login') return 4;
  final i = kMainTabPaths.indexOf(path);
  if (i >= 0) return i;
  return null;
}

void goMainTab(BuildContext context, int index) {
  if (index < 0 || index >= kMainTabPaths.length) return;
  final path = kMainTabPaths[index];
  final currentUri = GoRouterState.of(context).uri;
  if (currentUri.path == path) {
    if (path == '/home' && currentUri.query.isNotEmpty) {
      context.go('/home');
    }
    AppScrollReset.instance.resetForLocation(
      path == '/home' ? '/home' : currentUri.toString(),
    );
    if (path == '/reels') ReelsFeedReload.instance.bump();
    return;
  }
  context.go(path);
}
