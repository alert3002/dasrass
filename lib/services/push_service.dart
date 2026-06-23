import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../firebase_options.dart';
import '../router/app_router.dart';
import 'auth_service.dart';
import 'dastrass_api.dart';
import 'message_unread_hub.dart';
import 'notification_unread_hub.dart';

const _androidChannel = AndroidNotificationChannel(
  'dastrass_push',
  'Dastrass уведомления',
  description: 'Сообщения, подписки и новости',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// FCM: регистрация токена, foreground/background, навигация по тапу.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _lastToken;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint('[Push] Firebase not configured — run flutterfire configure');
      return;
    }

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      if (Platform.isAndroid) {
        final androidPlugin = _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(_androidChannel);
        final granted = await androidPlugin?.requestNotificationsPermission();
        debugPrint('[Push] Android notification permission: $granted');
      }

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed && Platform.isIOS) {
        debugPrint('[Push] iOS permission denied');
        return;
      }

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
      messaging.onTokenRefresh.listen((token) => _registerToken(token));

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        scheduleMicrotask(() => _handlePayload(initial.data));
      }

      AuthService.instance.addListener(_onAuthChanged);
      _ready = true;
      await syncToken();
    } catch (e, st) {
      debugPrint('[Push] init failed: $e\n$st');
    }
  }

  void _onAuthChanged() {
    if (AuthService.instance.isAuthenticated) {
      unawaited(syncToken());
    } else {
      unawaited(_unregisterCurrentToken());
    }
  }

  Future<void> syncToken() async {
    if (!_ready || !AuthService.instance.isAuthenticated) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (e) {
      debugPrint('[Push] getToken failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    if (!AuthService.instance.isAuthenticated) return;
    if (_lastToken == token) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await DastrassApi.instance.registerPushToken(token, platform);
      _lastToken = token;
      debugPrint('[Push] token registered (${token.substring(0, 12)}...)');
    } catch (e) {
      debugPrint('[Push] register failed: $e');
    }
  }

  Future<void> _unregisterCurrentToken() async {
    final token = _lastToken;
    _lastToken = null;
    if (token == null) return;
    try {
      await DastrassApi.instance.unregisterPushToken(token);
    } catch (_) {
      // Best effort on logout.
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    NotificationUnreadHub.instance.refresh();
    MessageUnreadHub.instance.refresh();

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Dastrass';
    final body = notification?.body ?? message.data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final android = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: android, iOS: const DarwinNotificationDetails()),
      payload: _encodePayload(message.data),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _handlePayload(message.data);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final data = _decodePayload(payload);
    _handlePayload(data);
  }

  void _handlePayload(Map<String, dynamic> data) {
    final type = '${data['type'] ?? ''}';
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    if (type == 'message') {
      final id = '${data['conversation_id'] ?? ''}';
      if (id.isNotEmpty) {
        context.go('/messages/chat/$id');
        return;
      }
      context.go('/messages');
      return;
    }

    if (type == 'notification') {
      context.go('/push');
      return;
    }

    final link = '${data['link_url'] ?? ''}';
    if (link.startsWith('/')) {
      context.go(link);
    }
  }

  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${Uri.encodeComponent('${e.value}')}').join('&');
  }

  Map<String, dynamic> _decodePayload(String payload) {
    final out = <String, dynamic>{};
    for (final part in payload.split('&')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      final key = part.substring(0, idx);
      final value = Uri.decodeComponent(part.substring(idx + 1));
      out[key] = value;
    }
    return out;
  }
}
