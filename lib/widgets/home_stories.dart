import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/dastrass_api.dart';
import '../theme/app_theme.dart';
import '../utils/ad_format.dart';

const _storyDuration = Duration(seconds: 12);
const _storyRingColor = Color(0xFFF1117E);

/// Горизонтальная лента историй — мисли [frontend/src/components/Stories.jsx].
class HomeStories extends StatefulWidget {
  const HomeStories({super.key});

  @override
  State<HomeStories> createState() => _HomeStoriesState();
}

class _HomeStoriesState extends State<HomeStories> {
  static const double _horizontalPadding = 16;
  static const double _itemGap = 10;
  static const int _visibleCount = 5;
  static const double _borderWidth = 2;
  static const double _captionBlock = 30;

  List<Map<String, dynamic>> _stories = [];
  final Map<int, bool> _viewed = {};
  bool _loading = true;

  ({double itemWidth, double outerSize, double innerSize, double rowHeight}) _sizes(
    double viewportWidth,
  ) {
    final available =
        viewportWidth - _horizontalPadding * 2 - _itemGap * (_visibleCount - 1);
    final itemWidth = available / _visibleCount;
    final outerSize = itemWidth;
    final innerSize = outerSize - _borderWidth * 2;
    return (
      itemWidth: itemWidth,
      outerSize: outerSize,
      innerSize: innerSize,
      rowHeight: outerSize + _captionBlock,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await DastrassApi.instance.stories();
      final viewed = <int, bool>{};
      final p = await SharedPreferences.getInstance();
      for (var i = 0; i < list.length; i++) {
        viewed[i] = p.getString(_storyKey(list[i])) == '1';
      }
      if (!mounted) return;
      setState(() {
        _stories = list;
        _viewed
          ..clear()
          ..addAll(viewed);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stories = [];
        _viewed.clear();
        _loading = false;
      });
    }
  }

  Future<void> _refreshViewed() async {
    final p = await SharedPreferences.getInstance();
    final next = <int, bool>{};
    for (var i = 0; i < _stories.length; i++) {
      next[i] = p.getString(_storyKey(_stories[i])) == '1';
    }
    if (!mounted) return;
    setState(() {
      _viewed
        ..clear()
        ..addAll(next);
    });
  }

  String _storyKey(Map<String, dynamic> s) {
    final t = '${s['approved_at'] ?? s['created_at'] ?? ''}';
    return 'story_${s['id']}_$t';
  }

  Future<void> _markViewed(Map<String, dynamic> s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_storyKey(s), '1');
  }

  Future<void> _openAt(int i) async {
    if (i < 0 || i >= _stories.length) return;
    await _markViewed(_stories[i]);
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _StoryViewerPage(stories: _stories, initialIndex: i),
      ),
    );
    await _refreshViewed();
  }

  Widget _buildThumbImage(
    String img, {
    required bool viewed,
    required double innerSize,
  }) {
    final iconSize = (innerSize * 0.42).clamp(20.0, 32.0);
    return Opacity(
      opacity: viewed ? 0.55 : 1,
      child: SizedBox(
        width: innerSize,
        height: innerSize,
        child: img.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.cover,
                width: innerSize,
                height: innerSize,
                memCacheWidth: (innerSize * 2.5).round(),
                errorWidget: (_, __, ___) => _thumbFallback(iconSize),
                placeholder: (_, __) => _thumbFallback(iconSize),
              )
            : _thumbFallback(iconSize),
      ),
    );
  }

  Widget _buildThumb(
    int index, {
    required double itemWidth,
    required double outerSize,
    required double innerSize,
  }) {
    final s = _stories[index];
    final img = normalizeMediaUrl('${s['image_url'] ?? ''}');
    final viewed = _viewed[index] == true;
    final caption = _caption('${s['title'] ?? 'Заголовок'}');

    return GestureDetector(
      onTap: () => _openAt(index),
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: outerSize,
              height: outerSize,
              padding: viewed ? EdgeInsets.zero : const EdgeInsets.all(_borderWidth),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: viewed ? Colors.transparent : _storyRingColor,
                border: viewed
                    ? Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.1),
                        width: 2,
                      )
                    : null,
              ),
              child: ClipOval(
                child: _buildThumbImage(img, viewed: viewed, innerSize: innerSize),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (itemWidth * 0.145).clamp(10.0, 12.0),
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _caption(String raw) {
    final t = raw.trim();
    if (t.length <= 14) return t;
    return '${t.substring(0, 14)}…';
  }

  Widget _thumbFallback(double iconSize) {
    return ColoredBox(
      color: AppColors.primary,
      child: Center(
        child: Icon(Icons.image_outlined, color: Colors.white54, size: iconSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _stories.isEmpty) return const SizedBox.shrink();

    final sizes = _sizes(MediaQuery.sizeOf(context).width);

    return SizedBox(
      height: sizes.rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding, vertical: 4),
        itemCount: _stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: _itemGap),
        itemBuilder: (context, i) => _buildThumb(
          i,
          itemWidth: sizes.itemWidth,
          outerSize: sizes.outerSize,
          innerSize: sizes.innerSize,
        ),
      ),
    );
  }
}

class _StoryViewerPage extends StatefulWidget {
  const _StoryViewerPage({required this.stories, required this.initialIndex});

  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  @override
  State<_StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<_StoryViewerPage> {
  late int _index;
  double _progress = 0;
  Timer? _timer;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    unawaited(_markViewedAt(_index));
    _startTimer();
  }

  String _storyKey(Map<String, dynamic> s) {
    final t = '${s['approved_at'] ?? s['created_at'] ?? ''}';
    return 'story_${s['id']}_$t';
  }

  Future<void> _markViewedAt(int i) async {
    if (i < 0 || i >= widget.stories.length) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_storyKey(widget.stories[i]), '1');
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _timer?.cancel();
    _progressTimer?.cancel();
  }

  void _startTimer() {
    _stopTimers();
    setState(() => _progress = 0);
    final started = DateTime.now();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(started);
      setState(() {
        _progress = (elapsed.inMilliseconds / _storyDuration.inMilliseconds).clamp(0.0, 1.0);
      });
    });
    _timer = Timer(_storyDuration, () async {
      if (!mounted) return;
      if (_index + 1 < widget.stories.length) {
        final next = _index + 1;
        setState(() => _index = next);
        await _markViewedAt(next);
        _startTimer();
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.stories.length) return;
    setState(() => _index = next);
    unawaited(_markViewedAt(next));
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];
    final img = normalizeMediaUrl('${story['image_url'] ?? ''}');
    final title = '${story['title'] ?? ''}';
    final vehicleId = int.tryParse('${story['vehicle_id'] ?? ''}') ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: List.generate(widget.stories.length, (i) {
                      final fill = i < _index ? 1.0 : (i == _index ? _progress : 0.0);
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: fill,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (img.isNotEmpty)
                        CachedNetworkImage(imageUrl: img, fit: BoxFit.contain)
                      else
                        const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.white38, size: 48),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => _go(-1),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => _go(1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (vehicleId > 0)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push('/ads/$vehicleId');
                      },
                      child: const Text('Открыть объявление'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
