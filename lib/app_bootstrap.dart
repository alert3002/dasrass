import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dastrass_app.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/compare_store.dart';
import 'services/dastrass_api.dart';
import 'services/favorites_store.dart';
import 'services/message_unread_hub.dart';
import 'services/notification_unread_hub.dart';
import 'services/push_service.dart';
import 'services/notifications_local_store.dart';
import 'theme/theme_controller.dart';
import 'utils/color_catalog.dart';
import 'utils/reels_feed_cache.dart';

/// Bootstrap without blocking splash: app opens immediately, warmup runs in background.
class DastrassBootstrap extends StatefulWidget {
  const DastrassBootstrap({super.key});

  @override
  State<DastrassBootstrap> createState() => _DastrassBootstrapState();
}

class _DastrassBootstrapState extends State<DastrassBootstrap> {
  /// Router ҳамон замон — бе экрани дуюми splash (танҳо native splash).
  final GoRouter _router = createAppRouter(AuthService.instance);

  @override
  void initState() {
    super.initState();
    unawaited(ThemeController.instance.load());
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await AuthService.instance.hydrate().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Fast startup first; background warmup will continue.
    }

    unawaited(PushService.instance.init());
    unawaited(_postBootstrapWarmups());
  }

  Future<void> _postBootstrapWarmups() async {
    try {
      await Future.wait([
        ColorCatalog.instance.ensureLoaded(),
        CompareStore.instance.hydrate(),
        FavoritesStore.instance.hydrate(),
        NotificationsLocalStore.instance.load(),
      ]).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Best effort.
    }
    NotificationUnreadHub.instance.start();
    MessageUnreadHub.instance.start();
    unawaited(_warmEssentialCaches());
  }

  Future<void> _warmEssentialCaches() async {
    try {
      final api = DastrassApi.instance;
      await Future.wait([
        api.categories(),
        api.homeSlides(),
        api.localitiesFlat(),
        api.tariffs(),
        api.ads({'limit': '10', 'shuffle': '1'}),
        ReelsFeedCache.instance.warmup(),
      ]).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Non-blocking best effort warmup.
    }
  }

  @override
  Widget build(BuildContext context) => DastrassApp(router: _router);
}
