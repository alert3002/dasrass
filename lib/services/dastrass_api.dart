import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'auth_service.dart';
import '../utils/shuffle_list.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode, this.code, this.details]);
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? details;

  @override
  String toString() => message;
}

class DastrassApi {
  DastrassApi._();
  static final DastrassApi instance = DastrassApi._();
  static const _cachePrefix = 'dastrass_api_cache_v1_';

  final Map<String, ({int ts, List<dynamic> data})> _listCacheMem = {};
  final Map<String, ({int ts, dynamic data})> _jsonCacheMem = {};

  Map<String, String> _headers({bool jsonBody = false}) {
    final h = <String, String>{
      'Accept': 'application/json',
    };
    if (jsonBody) h['Content-Type'] = 'application/json';
    final t = AuthService.instance.token;
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Token $t';
    }
    return h;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.base.replaceAll(RegExp(r'/+$'), '');
    var p = path;
    if (!p.startsWith('/')) p = '/$p';
    return Uri.parse('$base$p').replace(queryParameters: query);
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final res = await http.get(_uri(path, query), headers: _headers());
    return _decode(res);
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      _uri(path),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final raw = res.body;
    dynamic data;
    try {
      data = raw.isEmpty ? null : jsonDecode(raw);
    } on FormatException catch (_) {
      final t = raw.trimLeft();
      final oneLine = raw.replaceAll(RegExp(r'\s+'), ' ');
      final head = oneLine.length > 220 ? '${oneLine.substring(0, 220)}…' : oneLine;
      if (t.startsWith('<!DOCTYPE') || t.startsWith('<html')) {
        final cf = raw.contains('cdn-cgi') || raw.contains('cloudflare');
        final cfHint = cf && res.statusCode == 504
            ? ' Похоже, запрос ушёл на api.dastrass.com через Cloudflare (таймаут). '
                'Для локального Django в debug не задавайте API_BASE или укажите http://127.0.0.1:8000/api.'
            : '';
        throw ApiException(
          'Сервер вернул HTML (${res.statusCode}), а не JSON.$cfHint '
          'Проверьте API_BASE (онлайн: https://api.dasrass.com/api). '
          'Для локального Django: --dart-define=API_BASE=http://10.0.2.2:8000/api\n'
          'Ответ: $head',
          res.statusCode,
        );
      }
      throw ApiException('Ответ не JSON (${res.statusCode}): $head', res.statusCode);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (data is Map) {
        final map = data;
        if (map['ok'] == false && map['error'] != null) {
          final m = Map<String, dynamic>.from(map);
          throw ApiException(
            '${map['error']}',
            res.statusCode,
            m['code'] != null ? '${m['code']}' : null,
            m,
          );
        }
      }
      return data;
    }
    String msg = 'Ошибка запроса';
    String? code;
    Map<String, dynamic>? details;
    if (data is Map) {
      details = Map<String, dynamic>.from(data);
      if (data['error'] is String) msg = data['error'] as String;
      if (data['code'] != null) code = '${data['code']}';
    }
    throw ApiException(msg, res.statusCode, code, details);
  }

  String _cacheKey(String name) => '$_cachePrefix$name';

  Future<({int ts, List<dynamic> data})?> _readListCache(String name) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey(name));
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return null;
      final ts = int.tryParse('${parsed['ts'] ?? 0}') ?? 0;
      final data = parsed['data'];
      if (data is! List) return null;
      return (ts: ts, data: List<dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeListCache(String name, List<dynamic> data) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    _listCacheMem[name] = (ts: ts, data: List<dynamic>.from(data));
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKey(name), jsonEncode({'ts': ts, 'data': data}));
  }

  Future<({int ts, dynamic data})?> _readJsonCache(String name) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey(name));
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return null;
      final ts = int.tryParse('${parsed['ts'] ?? 0}') ?? 0;
      return (ts: ts, data: parsed['data']);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeJsonCache(String name, dynamic data) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    _jsonCacheMem[name] = (ts: ts, data: data);
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKey(name), jsonEncode({'ts': ts, 'data': data}));
  }

  bool _isFresh(int ts, Duration ttl) {
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    return age >= 0 && age <= ttl.inMilliseconds;
  }

  Future<List<dynamic>> _loadListWithCache({
    required String name,
    required Duration ttl,
    required Future<List<dynamic>> Function() fetch,
  }) async {
    final mem = _listCacheMem[name];
    if (mem != null && _isFresh(mem.ts, ttl)) {
      return List<dynamic>.from(mem.data);
    }

    final disk = await _readListCache(name);
    if (disk != null) {
      _listCacheMem[name] = (ts: disk.ts, data: List<dynamic>.from(disk.data));
      if (_isFresh(disk.ts, ttl)) {
        return List<dynamic>.from(disk.data);
      }
    }

    try {
      final fresh = await fetch();
      await _writeListCache(name, fresh);
      return fresh;
    } catch (_) {
      if (disk != null) return List<dynamic>.from(disk.data);
      if (mem != null) return List<dynamic>.from(mem.data);
      rethrow;
    }
  }

  Future<T> _loadJsonWithCache<T>({
    required String name,
    required Duration ttl,
    required Future<T> Function() fetch,
  }) async {
    final mem = _jsonCacheMem[name];
    if (mem != null && _isFresh(mem.ts, ttl)) {
      return mem.data as T;
    }

    final disk = await _readJsonCache(name);
    if (disk != null) {
      _jsonCacheMem[name] = (ts: disk.ts, data: disk.data);
      if (_isFresh(disk.ts, ttl)) {
        return disk.data as T;
      }
    }

    try {
      final fresh = await fetch();
      await _writeJsonCache(name, fresh);
      return fresh;
    } catch (_) {
      if (disk != null) return disk.data as T;
      if (mem != null) return mem.data as T;
      rethrow;
    }
  }

  String _queryCacheSuffix(Map<String, String> query) {
    final entries = query.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  // ——— публичные методы (как api.js) ———

  Future<List<dynamic>> categories() async {
    return _loadListWithCache(
      name: 'categories',
      ttl: const Duration(hours: 24),
      fetch: () async {
        final data = await get('/categories/');
        if (data is Map && data['results'] is List) {
          return List<dynamic>.from(data['results'] as List);
        }
        return [];
      },
    );
  }

  Map<String, dynamic> _asAdsMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'results': <dynamic>[], 'count': 0, 'total_count': 0};
  }

  String _adsShufflePoolKey(Map<String, String> query) {
    final q = Map<String, String>.from(query)
      ..remove('exclude')
      ..remove('offset');
    return 'ads_shuffle_pool_${_queryCacheSuffix(q)}';
  }

  bool _shouldStoreShufflePool(Map<String, String> query) =>
      (query['exclude'] ?? '').trim().isEmpty;

  Future<Map<String, dynamic>?> _readShufflePool(String poolKey) async {
    final mem = _jsonCacheMem[poolKey];
    if (mem != null) {
      return Map<String, dynamic>.from(mem.data as Map);
    }
    final disk = await _readJsonCache(poolKey);
    if (disk != null) {
      _jsonCacheMem[poolKey] = (ts: disk.ts, data: disk.data);
      return Map<String, dynamic>.from(disk.data as Map);
    }
    return null;
  }

  Map<String, dynamic> _offlineShuffledAds(
    Map<String, dynamic> map,
    Map<String, String> query,
  ) {
    var results = shuffleList(List<dynamic>.from((map['results'] as List?) ?? []));
    final excludeRaw = (query['exclude'] ?? '').trim();
    if (excludeRaw.isNotEmpty) {
      final exclude = excludeRaw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      results = results
          .where((a) {
            final id = '${(a as Map)['id'] ?? ''}';
            return id.isNotEmpty && !exclude.contains(id);
          })
          .toList();
      final limit = int.tryParse(query['limit'] ?? '20') ?? 20;
      if (results.length > limit) {
        results = results.take(limit).toList();
      }
    }
    return {...map, 'results': results};
  }

  /// Случайная лента: всегда свежий запрос онлайн; офлайн — из пула с локальным shuffle.
  Future<Map<String, dynamic>> _adsShuffled(Map<String, String> query) async {
    final poolKey = _adsShufflePoolKey(query);
    try {
      final data = await get('/ads/', query);
      final map = _asAdsMap(data);
      if (_shouldStoreShufflePool(query)) {
        await _writeJsonCache(poolKey, map);
      }
      return map;
    } catch (e) {
      final fallback = await _readShufflePool(poolKey);
      if (fallback != null) {
        return _offlineShuffledAds(fallback, query);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> ads(Map<String, String> query) async {
    final clean = Map<String, String>.from(query)..removeWhere((k, v) => v.trim().isEmpty);
    if (clean['shuffle'] == '1') {
      return _adsShuffled(clean);
    }
    final key = 'ads_${_queryCacheSuffix(clean)}';
    return _loadJsonWithCache<Map<String, dynamic>>(
      name: key,
      ttl: const Duration(minutes: 15),
      fetch: () async => _asAdsMap(await get('/ads/', clean)),
    );
  }

  /// Кэш детали объявления для мгновенного показа (офлайн / повторный вход).
  Future<Map<String, dynamic>?> cachedAdDetail(String id) async {
    final name = 'ad_detail_$id';
    final mem = _jsonCacheMem[name];
    if (mem != null && mem.data is Map) {
      return Map<String, dynamic>.from(mem.data as Map);
    }
    final disk = await _readJsonCache(name);
    if (disk != null && disk.data is Map) {
      _jsonCacheMem[name] = (ts: disk.ts, data: disk.data);
      return Map<String, dynamic>.from(disk.data as Map);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> colors() async {
    final list = await _loadListWithCache(
      name: 'colors',
      ttl: const Duration(days: 3),
      fetch: () async {
        final data = await get('/colors/');
        if (data is Map && data['results'] is List) {
          return List<dynamic>.from(data['results'] as List);
        }
        return [];
      },
    );
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> filterOptions({
    String? category,
    String? subcategory,
    String? brand,
  }) async {
    final q = <String, String>{};
    if (category != null && category.isNotEmpty) q['category'] = category;
    if (subcategory != null && subcategory.isNotEmpty) q['subcategory'] = subcategory;
    if (brand != null && brand.isNotEmpty) q['brand'] = brand;
    final key = 'filter_options_${_queryCacheSuffix(q)}';
    return _loadJsonWithCache<Map<String, dynamic>>(
      name: key,
      ttl: const Duration(hours: 6),
      fetch: () async {
        final data = await get('/filter-options/', q.isEmpty ? null : q);
        if (data is Map<String, dynamic>) return data;
        return {'brands': [], 'models': [], 'colors': []};
      },
    );
  }

  Future<Map<String, dynamic>> adDetail(String id) async {
    return _loadJsonWithCache<Map<String, dynamic>>(
      name: 'ad_detail_$id',
      ttl: const Duration(hours: 4),
      fetch: () async {
        final data = await get('/ads/$id/');
        if (data is Map) return Map<String, dynamic>.from(data);
        throw ApiException('Объявление не найдено');
      },
    );
  }

  /// Деталь с сервера без кэша: +1 просмотр на бэкенде, затем обновляет кэш.
  Future<Map<String, dynamic>> fetchAdDetailFresh(String id) async {
    final data = await get('/ads/$id/');
    if (data is! Map) throw ApiException('Объявление не найдено');
    final map = Map<String, dynamic>.from(data);
    await _writeJsonCache('ad_detail_$id', map);
    return map;
  }

  Future<List<Map<String, dynamic>>> stories() async {
    final list = await _loadListWithCache(
      name: 'stories',
      ttl: const Duration(minutes: 30),
      fetch: () async {
        final data = await get('/stories/', {'_': '${DateTime.now().millisecondsSinceEpoch}'});
        if (data is Map && data['results'] is List) {
          return List<dynamic>.from(data['results'] as List);
        }
        if (data is List) return List<dynamic>.from(data);
        return [];
      },
    );
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<dynamic>> homeSlides() async {
    return _loadListWithCache(
      name: 'home_slides',
      ttl: const Duration(hours: 12),
      fetch: () async {
        final data = await get('/home-slides/');
        if (data is Map && data['results'] is List) {
          return List<dynamic>.from(data['results'] as List);
        }
        return [];
      },
    );
  }

  Future<Map<String, dynamic>> requestOtp(String phone9, bool agree) async {
    final data = await postJson('/auth/request-otp/', {
      'phone': phone9,
      'agree': agree,
    });
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<Map<String, dynamic>> verifyOtp(String phone9, String code) async {
    final data = await postJson('/auth/verify-otp/', {
      'phone': phone9,
      'code': code,
    });
    if (data is Map<String, dynamic>) return data;
    throw ApiException('Неверный ответ сервера');
  }

  Future<Map<String, dynamic>?> me() async {
    if (!AuthService.instance.isAuthenticated) return null;
    final data = await get('/auth/me/');
    if (data is Map && data['ok'] == true) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<List<dynamic>> favorites() async {
    final data = await get('/favorites/');
    if (data is Map && data['results'] is List) {
      return List<dynamic>.from(data['results'] as List);
    }
    return [];
  }

  Future<List<dynamic>> messageThreads() async {
    final data = await get('/auth/messages/threads/');
    if (data is Map && data['results'] is List) {
      return List<dynamic>.from(data['results'] as List);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> messageDetail(String conversationId) async {
    final data = await get('/auth/messages/$conversationId/');
    if (data is Map && data['results'] is List) {
      return (data['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> messageSend({
    required String text,
    int? conversationId,
    int? vehicleId,
    String? toPhone,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (conversationId != null) body['conversation_id'] = conversationId;
    if (vehicleId != null) body['vehicle_id'] = vehicleId;
    if (toPhone != null && toPhone.isNotEmpty) body['to_phone'] = toPhone;
    final data = await postJson('/auth/messages/send/', body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<int> messagesUnreadCount() async {
    final data = await get('/auth/messages/unread-count/');
    if (data is Map && data['unread'] != null) {
      return int.tryParse('${data['unread']}') ?? 0;
    }
    return 0;
  }

  Future<int> notificationsUnreadCount() async {
    final data = await get('/auth/notifications/unread-count/');
    if (data is Map && data['ok'] == true && data['count'] != null) {
      return int.tryParse('${data['count']}') ?? 0;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> notificationsList() async {
    final data = await get('/auth/notifications/');
    if (data is Map && data['ok'] == true && data['results'] is List) {
      return (data['results'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<void> notificationsMarkAllRead() async {
    await postJson('/auth/notifications/mark-read/', {});
  }

  Future<void> notificationMarkRead(int id) async {
    await postJson('/auth/notifications/$id/mark-read/', {});
  }

  Future<void> registerPushToken(String token, String platform) async {
    await postJson('/auth/push/register/', {
      'token': token,
      'platform': platform,
    });
  }

  Future<void> unregisterPushToken(String token) async {
    await postJson('/auth/push/unregister/', {'token': token});
  }

  /// POST `/ads/{id}/favorite/` — мисли `apiAdAction(..., 'favorite')` дар фронтенд.
  Future<Map<String, dynamic>> toggleFavorite(String id) async {
    final data = await postJson('/ads/$id/favorite/', {});
    if (data is Map<String, dynamic>) return data;
    return {'ok': false};
  }

  /// POST `/stories/request/` — мисли `apiRequestStory` дар React.
  Future<Map<String, dynamic>> requestStory(String vehicleId) async {
    final vid = int.tryParse(vehicleId) ?? vehicleId;
    final data = await postJson('/stories/request/', {'vehicle_id': vid});
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'ok': false};
  }

  Future<List<dynamic>> tariffs() async {
    return _loadListWithCache(
      name: 'tariffs',
      ttl: const Duration(hours: 12),
      fetch: () async {
        final data = await get('/tariffs/');
        if (data is Map && data['results'] is List) {
          return List<dynamic>.from(data['results'] as List);
        }
        return [];
      },
    );
  }

  Future<List<Map<String, dynamic>>> localitiesFlat() async {
    final list = await _loadListWithCache(
      name: 'localities_flat',
      ttl: const Duration(hours: 12),
      fetch: () async {
        final data = await get('/localities/');
        if (data is Map && data['flat'] is List) {
          return List<dynamic>.from(data['flat'] as List);
        }
        return [];
      },
    );
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// POST `/ads/create/` — `multipart/form-data` (Dio барои `onSendProgress`).
  Future<Map<String, dynamic>> createAd({
    required Map<String, String> fields,
    required List<({Uint8List bytes, String filename})> photos,
    ({Uint8List bytes, String filename})? video,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    if (photos.isEmpty) {
      throw ApiException('Добавьте хотя бы 1 фотографию');
    }
    final uri = _uri('/ads/create/');
    final dio = Dio(
      BaseOptions(
        headers: _headers(),
        validateStatus: (s) => (s ?? 600) < 600,
      ),
    );
    final form = FormData();
    for (final e in fields.entries) {
      form.fields.add(MapEntry(e.key, e.value));
    }
    for (final p in photos) {
      form.files.add(
        MapEntry(
          'photos',
          MultipartFile.fromBytes(p.bytes, filename: p.filename),
        ),
      );
    }
    if (video != null) {
      form.files.add(
        MapEntry(
          'video',
          MultipartFile.fromBytes(video.bytes, filename: video.filename),
        ),
      );
    }
    final res = await dio.post<Map<String, dynamic>>(
      uri.toString(),
      data: form,
      onSendProgress: onSendProgress,
    );
    final data = res.data;
    final sc = res.statusCode ?? 500;
    if (sc >= 200 && sc < 300) {
      if (data != null && data['ok'] == false) {
        final msg = '${data['error'] ?? 'Не удалось создать объявление'}';
        final c = data['code'] != null ? '${data['code']}' : null;
        throw ApiException(msg, sc, c, Map<String, dynamic>.from(data));
      }
      if (data != null) return data;
      throw ApiException('Неверный ответ сервера', sc);
    }
    String msg = 'Ошибка запроса';
    String? code;
    Map<String, dynamic>? det;
    final errBody = data;
    if (errBody is Map) {
      final m = Map<String, dynamic>.from(errBody as Map<dynamic, dynamic>);
      det = m;
      if (m['error'] is String) msg = m['error'] as String;
      if (m['code'] != null) code = '${m['code']}';
    }
    throw ApiException(msg, sc, code, det);
  }

  /// POST `/ads/{id}/update/` — multipart, мисли [frontend/src/api.js] `apiUpdateAd`.
  Future<Map<String, dynamic>> updateAd({
    required String id,
    required Map<String, String> fields,
  }) async {
    final uri = _uri('/ads/$id/update/');
    final dio = Dio(
      BaseOptions(
        headers: _headers(),
        validateStatus: (s) => (s ?? 600) < 600,
      ),
    );
    final form = FormData();
    for (final e in fields.entries) {
      form.fields.add(MapEntry(e.key, e.value));
    }
    final res = await dio.post<Map<String, dynamic>>(uri.toString(), data: form);
    final data = res.data;
    final sc = res.statusCode ?? 500;
    if (sc >= 200 && sc < 300) {
      if (data != null && data['ok'] == false) {
        final msg = '${data['error'] ?? 'Не удалось обновить объявление'}';
        final c = data['code'] != null ? '${data['code']}' : null;
        throw ApiException(msg, sc, c, Map<String, dynamic>.from(data));
      }
      if (data != null) return data;
      throw ApiException('Неверный ответ сервера', sc);
    }
    String msg = 'Ошибка запроса';
    String? code;
    Map<String, dynamic>? det;
    final errBody = data;
    if (errBody is Map) {
      final m = Map<String, dynamic>.from(errBody as Map<dynamic, dynamic>);
      det = m;
      if (m['error'] is String) msg = m['error'] as String;
      if (m['code'] != null) code = '${m['code']}';
    }
    throw ApiException(msg, sc, code, det);
  }

  Future<List<dynamic>> myAds({int limit = 200}) async {
    final data = await get('/my-ads/', {'limit': '$limit'});
    if (data is Map && data['ok'] == true && data['results'] is List) {
      return List<dynamic>.from(data['results'] as List);
    }
    return [];
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? dateOfBirth,
  }) async {
    await postJson('/auth/profile-update/', {
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth ?? '',
    });
  }

  Future<void> deleteAccount() async {
    final data = await postJson('/auth/delete-account/', {});
    if (data is Map && data['ok'] != true) {
      throw ApiException('${data['error'] ?? 'Не удалось удалить аккаунт'}');
    }
  }

  Future<Map<String, dynamic>> uploadProfileAvatar(Uint8List bytes, String filename) async {
    final uri = _uri('/auth/profile-avatar/');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_headers());
    req.files.add(http.MultipartFile.fromBytes('avatar', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final data = _decode(res);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException('Неверный ответ сервера');
  }

  Future<List<Map<String, dynamic>>> myPayments() async {
    final data = await get('/auth/payments/');
    if (data is Map && data['ok'] == true && data['results'] is List) {
      return (data['results'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> myAdAction(String id, String action) async {
    final data = await postJson('/ads/$id/action/', {'action': action});
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> createTopup(num amount) async {
    final data = await postJson('/auth/topup/', {'amount': amount});
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException('Неверный ответ сервера');
  }

  Future<List<Map<String, dynamic>>> filterSubscriptions() async {
    final data = await get('/auth/subscriptions/');
    if (data is Map && data['ok'] == true && data['results'] is List) {
      return (data['results'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createFilterSubscription(Map<String, String> filters) async {
    final data = await postJson('/auth/subscriptions/', {'filters': filters});
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException('Неверный ответ сервера');
  }

  Future<void> updateFilterSubscription(int id, Map<String, dynamic> patch) async {
    final res = await http.patch(
      _uri('/auth/subscriptions/$id/'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(patch),
    );
    final data = _decode(res);
    if (data is Map && data['ok'] == false) {
      throw ApiException('${data['error'] ?? 'Ошибка'}');
    }
  }

  Future<void> deleteFilterSubscription(int id) async {
    final res = await http.delete(
      _uri('/auth/subscriptions/$id/'),
      headers: _headers(),
    );
    final data = _decode(res);
    if (data is Map && data['ok'] == false) {
      throw ApiException('${data['error'] ?? 'Ошибка'}');
    }
  }
}
