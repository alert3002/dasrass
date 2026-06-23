import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Кэши видеоҳои Reels дар диск — барои такрор ва swipe зудтар.
class ReelsVideoCache {
  ReelsVideoCache._();

  static final instance = ReelsVideoCache._();

  static final _manager = CacheManager(
    Config(
      'dastrass_reels_videos',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 60,
    ),
  );

  final Map<String, Future<File>> _inFlight = {};
  final Set<String> _prefetching = {};
  static const _maxConcurrentPrefetch = 2;
  int _activePrefetch = 0;
  final List<String> _prefetchQueue = [];

  /// Файли пурраи кэшшуда (агар бошад).
  Future<File?> getCachedFile(String url) async {
    if (url.isEmpty) return null;
    try {
      final info = await _manager.getFileFromCache(url);
      final file = info?.file;
      if (file != null && await file.exists() && await file.length() > 0) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Боргирӣ ё аз кэш — барои playback.
  Future<File> getFile(String url) {
    if (url.isEmpty) {
      return Future.error(ArgumentError('empty url'));
    }
    return _inFlight.putIfAbsent(url, () async {
      try {
        final file = await _manager.getSingleFile(url);
        if (!await file.exists() || await file.length() == 0) {
          throw StateError('empty video file');
        }
        return file;
      } finally {
        _inFlight.remove(url);
      }
    });
  }

  /// Боргирӣ дар фон (бе интизорӣ), ҳадди аксар 2 ҳамзамон.
  void prefetch(String url) {
    if (url.isEmpty || _prefetching.contains(url)) return;
    _prefetchQueue.add(url);
    _drainPrefetchQueue();
  }

  void _drainPrefetchQueue() {
    while (_activePrefetch < _maxConcurrentPrefetch && _prefetchQueue.isNotEmpty) {
      final url = _prefetchQueue.removeAt(0);
      if (url.isEmpty || _prefetching.contains(url)) continue;
      _prefetching.add(url);
      _activePrefetch++;
      unawaited(
        getCachedFile(url).then((cached) {
          if (cached != null) return cached;
          return getFile(url);
        }).whenComplete(() {
          _prefetching.remove(url);
          _activePrefetch--;
          _drainPrefetchQueue();
        }).catchError((_) => File('')),
      );
    }
  }

  void prefetchMany(Iterable<String> urls) {
    for (final url in urls) {
      prefetch(url);
    }
  }
}
