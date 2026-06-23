import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/add_ad_screen.dart';
import '../screens/ad_detail_screen.dart';
import '../screens/ads_list_screen.dart';
import '../screens/edit_ad_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/legal_screens.dart';
import '../screens/login_screen.dart';
import '../screens/message_thread_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/reels_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_scroll_reset.dart';
import '../widgets/dastrass_outer_tab_shell.dart';
import '../widgets/dastrass_tab_shell.dart';
import '../widgets/page_scroll_host.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

String _routeKey(GoRouterState state) => state.uri.toString();

Widget _scrollPage(String routeKey, Widget child) {
  return PageScrollHost(routeKey: routeKey, child: child);
}

GoRouter createAppRouter(AuthService auth) {
  late final GoRouter router;
  router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: auth,
    errorBuilder: (context, state) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Ошибка навигации: ${state.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDark),
            ),
          ),
        ),
      );
    },
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final authed = auth.isAuthenticated;
      const needAuth = ['/messages', '/profile', '/add'];
      if (!authed &&
          (needAuth.contains(loc) || loc.startsWith('/edit/') || loc.startsWith('/messages/chat/'))) {
        return '/login?redirect=${Uri.encodeComponent(loc)}';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),
      ShellRoute(
        builder: (context, state, child) {
          return DastrassOuterTabShell(
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: [
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return DastrassTabShell(navigationShell: navigationShell);
        },
        navigatorContainerBuilder: (context, navigationShell, children) {
          // Танҳо таби фаъол — суръати кушодан (на ҳамаи 4 экран ҳамзамон).
          final i = navigationShell.currentIndex;
          if (i < 0 || i >= children.length) return children.first;
          return children[i];
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  child: _scrollPage(_routeKey(state), const HomeScreen()),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reels',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  child: _scrollPage(_routeKey(state), const ReelsScreen()),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  child: _scrollPage(_routeKey(state), const AddAdScreen()),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                pageBuilder: (context, state) {
                  final tab = state.uri.queryParameters['tab'];
                  final initialTab = tab == 'compare' ? 1 : 0;
                  return NoTransitionPage<void>(
                    child: _scrollPage(
                      _routeKey(state),
                      FavoritesScreen(initialTab: initialTab),
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  child: _scrollPage(_routeKey(state), const ProfileScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) =>
            _scrollPage(_routeKey(state), const MessagesScreen()),
      ),
      GoRoute(
        path: '/messages/chat/:conversationId',
        builder: (context, state) {
          final id = state.pathParameters['conversationId'] ?? '';
          String? title;
          String? sub;
          final ex = state.extra;
          if (ex is Map) {
            final m = Map<String, dynamic>.from(ex);
            final t = '${m['title'] ?? ''}'.trim();
            final s = '${m['sub'] ?? ''}'.trim();
            if (t.isNotEmpty) title = t;
            if (s.isNotEmpty) sub = s;
          }
          return _scrollPage(
            _routeKey(state),
            MessageThreadScreen(
              conversationId: id,
              titleHint: title,
              subtitleHint: sub,
            ),
          );
        },
      ),
      GoRoute(
        path: '/edit/ads/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return _scrollPage(_routeKey(state), EditAdScreen(adId: id));
        },
      ),
      GoRoute(
        path: '/push',
        builder: (context, state) =>
            _scrollPage(_routeKey(state), const NotificationsScreen()),
      ),
      GoRoute(
        path: '/compare',
        redirect: (context, state) => '/favorites?tab=compare',
      ),
      GoRoute(
        path: '/add-ad',
        redirect: (context, state) => '/add',
      ),
      GoRoute(
        path: '/register',
        redirect: (context, state) {
          final from = state.uri.queryParameters['redirect'] ?? state.uri.queryParameters['from'];
          if (from != null && from.isNotEmpty) {
            return '/login?redirect=${Uri.encodeComponent(from)}';
          }
          return '/login';
        },
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) =>
            _scrollPage(_routeKey(state), const AboutScreen()),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) =>
            _scrollPage(_routeKey(state), const TermsScreen()),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) =>
            _scrollPage(_routeKey(state), const PrivacyScreen()),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          return _scrollPage(
            _routeKey(state),
            LoginScreen(redirectTo: redirect),
          );
        },
      ),
      GoRoute(
        path: '/ads',
        builder: (context, state) {
          final q = Map<String, String>.from(state.uri.queryParameters);
          return _scrollPage(_routeKey(state), AdsListScreen(query: q));
        },
      ),
      GoRoute(
        path: '/ads/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return _scrollPage(_routeKey(state), AdDetailScreen(id: id));
        },
      ),
        ],
      ),
    ],
  );
  router.routerDelegate.addListener(() {
    final matches = router.routerDelegate.currentConfiguration;
    if (matches.isEmpty) return;
    AppScrollReset.instance.onLocationChanged(matches.uri.toString());
  });
  return router;
}
