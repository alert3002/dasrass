import 'dart:async';

import '../services/dastrass_api.dart';
import '../services/reels_video_cache.dart';
import '../utils/ad_format.dart';
import '../utils/shuffle_list.dart';

/// Кэши лентаи Reels дар хотира — кушодани таб бе API-и аз нав.
class ReelsFeedCache {
  ReelsFeedCache._();

  static final instance = ReelsFeedCache._();

  static const _staleAfter = Duration(minutes: 8);
  static const _apiLimit = 40;

  List<Map<String, dynamic>> _items = [];
  DateTime? _loadedAt;
  Future<void>? _warmupFuture;

  bool get hasItems => _items.isNotEmpty;

  bool get isFresh {
    final at = _loadedAt;
    if (at == null || _items.isEmpty) return false;
    return DateTime.now().difference(at) < _staleAfter;
  }

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  void store(List<Map<String, dynamic>> raw) {
    _items = raw
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => '${e['video_url'] ?? ''}'.trim().isNotEmpty)
        .toList();
    _loadedAt = DateTime.now();
    _prefetchLeadingVideos(_items);
  }

  List<Map<String, dynamic>> shuffledItems() => shuffleList(List<Map<String, dynamic>>.from(_items));

  /// Фон: API + prefetch видеои аввал.
  Future<void> warmup() {
    _warmupFuture ??= _fetch();
    return _warmupFuture!;
  }

  Future<void> refresh({bool force = false}) async {
    if (!force && isFresh) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await DastrassApi.instance.ads({
        'limit': '$_apiLimit',
        'shuffle': '1',
        'reels': '1',
      });
      final raw = (data['results'] as List<dynamic>?) ?? [];
      final list = <Map<String, dynamic>>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        if ('${m['video_url'] ?? ''}'.trim().isEmpty) continue;
        list.add(m);
      }
      if (list.isEmpty) return;
      _items = list;
      _loadedAt = DateTime.now();
      _prefetchLeadingVideos(list);
    } catch (_) {}
  }

  void _prefetchLeadingVideos(List<Map<String, dynamic>> list) {
    for (var i = 0; i < 2 && i < list.length; i++) {
      final url = normalizeMediaUrl('${list[i]['video_url'] ?? ''}');
      if (url.isNotEmpty) {
        ReelsVideoCache.instance.prefetch(url);
      }
    }
  }
}
