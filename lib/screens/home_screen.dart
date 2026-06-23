import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/ad_listing_grid.dart';
import '../widgets/ad_listing_layout.dart';
import '../widgets/home_stories.dart';

import '../services/dastrass_api.dart';
import '../theme/app_theme.dart';
import '../utils/category_icons.dart';
import '../utils/ad_format.dart';
import '../utils/network_error_message.dart';
import '../utils/shuffle_list.dart';
import '../widgets/dastrass_logo.dart';
import '../widgets/dastrass_mobile_tab_bar.dart';
import '../widgets/progressive_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;
  static const int _kAdsPageSize = 10;
  static const Duration _kLoadMoreFallbackDelay = Duration(seconds: 4);
  static const double _kLoadMoreScrollThreshold = 320;

  List<dynamic> _displayedAds = [];
  int _adsTotal = 0;
  bool _loadingMore = false;
  bool _showLoadMoreButton = false;
  bool _internetUnavailable = false;
  Timer? _loadFallbackTimer;

  String? _activeSearchQ;
  List<dynamic> _searchAds = [];
  int _searchTotal = 0;
  bool _searchLoading = false;
  String? _searchError;

  static const int _kSearchPreviewLimit = 8;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _loadFallbackTimer?.cancel();
    super.dispose();
  }

  String _searchQueryFromRoute(BuildContext context) =>
      GoRouterState.of(context).uri.queryParameters['q']?.trim() ?? '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final q = _searchQueryFromRoute(context);
    if (q == _activeSearchQ) return;
    _activeSearchQ = q;
    if (q.isEmpty) {
      if (_searchAds.isNotEmpty || _searchLoading || _searchError != null) {
        setState(() {
          _searchAds = [];
          _searchTotal = 0;
          _searchLoading = false;
          _searchError = null;
        });
      }
      return;
    }
    unawaited(_loadSearch(q));
  }

  Future<void> _loadSearch(String q) async {
    setState(() {
      _searchLoading = true;
      _searchError = null;
    });
    try {
      final data = await DastrassApi.instance.ads({
        'q': q,
        'limit': '$_kSearchPreviewLimit',
      });
      if (!mounted || _activeSearchQ != q) return;
      final results = (data['results'] as List<dynamic>?) ?? [];
      final total = int.tryParse('${data['total_count']}') ?? results.length;
      setState(() {
        _searchAds = results;
        _searchTotal = total;
        _searchLoading = false;
      });
    } catch (e) {
      if (!mounted || _activeSearchQ != q) return;
      setState(() {
        _searchLoading = false;
        _searchError = friendlyLoadErrorMessage(e);
      });
    }
  }

  bool get _hasMore => _displayedAds.isNotEmpty && _displayedAds.length < _adsTotal;

  void _onScrollNearBottom() {
    _triggerAutoLoadMore();
  }

  void _scheduleContentFitCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = PrimaryScrollController.maybeOf(context);
      if (!mounted || controller == null || !controller.hasClients) return;
      final pos = controller.position;
      final nearBottom = pos.pixels >= pos.maxScrollExtent - _kLoadMoreScrollThreshold;
      final shortContent = pos.maxScrollExtent <= 80;
      if (_hasMore && !_loadingMore && (nearBottom || shortContent)) {
        _triggerAutoLoadMore();
      }
    });
  }

  void _triggerAutoLoadMore() {
    if (_loadingMore || !_hasMore) return;

    _loadFallbackTimer?.cancel();
    _loadFallbackTimer = Timer(_kLoadMoreFallbackDelay, () {
      if (!mounted) return;
      if (_hasMore && _loadingMore) {
        setState(() => _showLoadMoreButton = true);
      }
    });

    unawaited(_loadMore(fromAuto: true));
  }

  void _onLoadMorePressed() {
    if (_loadingMore || !_hasMore) return;
    setState(() => _showLoadMoreButton = false);
    unawaited(_loadMore(fromAuto: false));
  }

  Widget _wrapHomeScroll(Widget child) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is! ScrollUpdateNotification &&
            notification is! ScrollEndNotification) {
          return false;
        }
        final metrics = notification.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - _kLoadMoreScrollThreshold) {
          _onScrollNearBottom();
        }
        return false;
      },
      child: child,
    );
  }

  bool _isConnectivityError(Object error) => isConnectivityError(error);

  Future<T> _safe<T>(
    Future<T> Function() run,
    T fallback, {
    required void Function(Object error) onError,
    void Function()? onSuccess,
  }) async {
    try {
      final value = await run();
      onSuccess?.call();
      return value;
    } catch (e) {
      onError(e);
      return fallback;
    }
  }

  Future<_HomeData> _load() async {
    final api = DastrassApi.instance;
    var connectivityErrors = 0;
    var successfulCalls = 0;
    final slides = await _safe<List<dynamic>>(
      () => api.homeSlides(),
      const <dynamic>[],
      onError: (e) {
        if (_isConnectivityError(e)) connectivityErrors++;
      },
      onSuccess: () => successfulCalls++,
    );
    final cats = await _safe<List<dynamic>>(
      () => api.categories(),
      const <dynamic>[],
      onError: (e) {
        if (_isConnectivityError(e)) connectivityErrors++;
      },
      onSuccess: () => successfulCalls++,
    );
    final ads = await _safe<Map<String, dynamic>>(
      () => api.ads({
        'limit': '$_kAdsPageSize',
        'shuffle': '1',
      }),
      <String, dynamic>{'results': <dynamic>[], 'total_count': 0},
      onError: (e) {
        if (_isConnectivityError(e)) connectivityErrors++;
      },
      onSuccess: () => successfulCalls++,
    );
    final results = (ads['results'] as List<dynamic>?) ?? [];
    final total = int.tryParse('${ads['total_count']}') ?? results.length;
    if (mounted) {
      setState(() {
        _displayedAds = shuffleList(List<dynamic>.from(results));
        _adsTotal = total;
        _loadingMore = false;
        _showLoadMoreButton = false;
        // Show "no internet" only if all critical calls failed by connectivity.
        _internetUnavailable = connectivityErrors >= 3 && successfulCalls == 0;
      });
      AdImagePrefetch.prefetchFromAds(results);
      _scheduleContentFitCheck();
    }
    return _HomeData(slides: slides, categories: cats);
  }

  Future<void> _loadMore({bool fromAuto = false}) async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      if (fromAuto) _showLoadMoreButton = false;
    });
    try {
      final exclude = _displayedAds
          .map((a) => '${(a as Map)['id'] ?? ''}')
          .where((id) => id.isNotEmpty)
          .join(',');
      final ads = await DastrassApi.instance.ads({
        'limit': '$_kAdsPageSize',
        'shuffle': '1',
        if (exclude.isNotEmpty) 'exclude': exclude,
      });
      final results = (ads['results'] as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        final seen = _displayedAds.map((a) => '${(a as Map)['id']}').toSet();
        for (final item in results) {
          final id = '${(item as Map)['id'] ?? ''}';
          if (id.isNotEmpty && !seen.contains(id)) {
            _displayedAds.add(item);
            seen.add(id);
          }
        }
        _loadingMore = false;
        _showLoadMoreButton = false;
      });
      AdImagePrefetch.prefetchFromAds(results);
      _loadFallbackTimer?.cancel();
      if (fromAuto) {
        _scheduleContentFitCheck();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _showLoadMoreButton = true;
      });
      _loadFallbackTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQ = _searchQueryFromRoute(context);
    if (searchQ.isNotEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _loadSearch(searchQ),
          child: _buildSearchResults(context, searchQ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          _loadFallbackTimer?.cancel();
          setState(() {
            _showLoadMoreButton = false;
            _future = _load();
          });
          await _future;
        },
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 80),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      friendlyLoadErrorMessage(snap.error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              );
            }
            if (!snap.hasData) {
              // Бе loader — ҳамон фон, таб-бар намоён; маълумот дар фон бор мешавад.
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, kTabScrollBottomPadding),
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 8)],
              );
            }
            final d = snap.data!;
            if (_internetUnavailable &&
                _displayedAds.isEmpty &&
                d.categories.isEmpty &&
                d.slides.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, kTabScrollBottomPadding),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          internetUnavailableTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          internetUnavailableRefreshHint,
                          style: TextStyle(
                            height: 1.35,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            setState(() => _future = _load());
                            await _future;
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Обновить'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1024;
                final main = _HomeMainColumn(
                  data: d,
                  wide: wide,
                  displayedAds: _displayedAds,
                  adsTotal: _adsTotal,
                  loadingMore: _loadingMore,
                  showLoadMoreButton: _showLoadMoreButton,
                  onLoadMore: _onLoadMorePressed,
                );
                if (!wide) {
                  return _wrapHomeScroll(
                    ListView(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, kTabScrollBottomPadding),
                      children: [main],
                    ),
                  );
                }
                return _wrapHomeScroll(
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, kTabScrollBottomPadding),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: main),
                          const SizedBox(width: 20),
                          const SizedBox(
                            width: 300,
                            child: _HomeAdSlot(),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, String searchQ) {
    if (_searchLoading && _searchAds.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }
    if (_searchError != null && _searchAds.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Text(
            _searchError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor, height: 1.35),
          ),
        ],
      );
    }
    if (_searchAds.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Text(
            'По запросу «$searchQ» ничего не найдено.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor, height: 1.35),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, kTabScrollBottomPadding),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AdListingCardLayout.pagePaddingH),
          child: Text(
            'Результаты поиска',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
          ),
        ),
        const SizedBox(height: 10),
        AdListingGrid(
          ads: _searchAds.cast<Map<String, dynamic>>(),
          padding: const EdgeInsets.symmetric(horizontal: AdListingCardLayout.pagePaddingH),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
        if (_searchTotal > _kSearchPreviewLimit) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => context.push(
                Uri(path: '/ads', queryParameters: {'q': searchQ}).toString(),
              ),
              icon: const Icon(Icons.expand_more_rounded, size: 22),
              label: const Text(
                'Загрузить ещё',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _HomeAdSlot extends StatelessWidget {
  const _HomeAdSlot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 420,
      width: double.infinity,
    );
  }
}

class _HomeMainColumn extends StatelessWidget {
  const _HomeMainColumn({
    required this.data,
    required this.wide,
    required this.displayedAds,
    required this.adsTotal,
    required this.loadingMore,
    required this.showLoadMoreButton,
    required this.onLoadMore,
  });

  final _HomeData data;
  final bool wide;
  final List<dynamic> displayedAds;
  final int adsTotal;
  final bool loadingMore;
  final bool showLoadMoreButton;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!wide) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: data.slides.isNotEmpty
                ? _SlideBanner(slides: data.slides)
                : const _HomeFallbackBanner(),
          ),
          const SizedBox(height: 10),
        ],
        if (wide)
          _HomeCategoryTwoRows(categories: data.categories)
        else
          _CategoryTwoRowStrip(categories: data.categories),
        const SizedBox(height: 12),
        const HomeStories(),
        const SizedBox(height: 14),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 0 : AdListingCardLayout.pagePaddingH,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Рекомендация',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 10),
              if (displayedAds.isEmpty)
                SizedBox(
                  height: 80,
                  child: Center(
                    child: Text(
                      'Нет объявлений',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdListingGrid(
                      ads: displayedAds.cast<Map<String, dynamic>>(),
                      shrinkWrap: true,
                    ),
                    if (displayedAds.length < adsTotal) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: loadingMore && !showLoadMoreButton
                            ? const SizedBox(height: 8)
                            : showLoadMoreButton
                                ? OutlinedButton.icon(
                                    onPressed: loadingMore ? null : onLoadMore,
                                    icon: loadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary,
                                            ),
                                          )
                                        : const Icon(Icons.expand_more_rounded, size: 22),
                                    label: Text(
                                      loadingMore ? 'Загрузка…' : 'Загрузить ещё',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary, width: 1.4),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                  )
                                : const SizedBox(height: 8),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeData {
  _HomeData({
    required this.slides,
    required this.categories,
  });
  final List<dynamic> slides;
  final List<dynamic> categories;
}

class _SlideBanner extends StatefulWidget {
  const _SlideBanner({required this.slides});
  final List<dynamic> slides;

  @override
  State<_SlideBanner> createState() => _SlideBannerState();
}

class _SlideBannerState extends State<_SlideBanner> {
  static const double _kRadiusMobile = 16;
  static const double _kRadiusDesktop = 18;

  final _controller = PageController();
  int _i = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _startAutoIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _SlideBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = widget.slides.length;
    final was = oldWidget.slides.length;
    if (was <= 1 && n > 1) {
      _startAutoIfNeeded();
    } else if (was > 1 && n <= 1) {
      _autoTimer?.cancel();
      _autoTimer = null;
    }
  }

  void _startAutoIfNeeded() {
    _autoTimer?.cancel();
    if (widget.slides.length <= 1) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final n = widget.slides.length;
      if (n <= 1) return;
      final next = (_i + 1) % n;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSlide(String raw) async {
    final u = raw.trim();
    if (u.isEmpty) {
      if (context.mounted) context.go('/');
      return;
    }
    final lower = u.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(u);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    final path = u.startsWith('/') ? u : '/$u';
    if (context.mounted) context.push(path);
  }

  void _goRelative(int delta) {
    final n = widget.slides.length;
    if (n <= 1) return;
    final next = (_i + delta + n) % n;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.slides.length;
    final w = MediaQuery.sizeOf(context).width;
    final wide = w > 1024;
    final sliderH = wide ? 450.0 : 178.0;
    final radius = wide ? _kRadiusDesktop : _kRadiusMobile;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final navSize = wide ? 44.0 : 30.0;
    final navIcon = wide ? 26.0 : 18.0;
    final navInset = wide ? 12.0 : 6.0;
    final dotsBottom = wide ? 10.0 : 4.0;
    final dotGap = wide ? 8.0 : 6.0;
    final dotSize = wide ? 8.0 : 6.0;
    final dotActiveW = wide ? 22.0 : 16.0;
    final navBg = dark ? const Color(0xF2131B2E) : const Color(0xE6FFFFFF);
    final navFg = dark ? AppColors.textDark : const Color(0xFF1A1F36);
    final shadowColor = dark ? Colors.black.withValues(alpha: 0.38) : Colors.black.withValues(alpha: 0.06);

    return Semantics(
      label: 'Слайдер',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: dark ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            height: sliderH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  dragStartBehavior: DragStartBehavior.down,
                  itemCount: n,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (context, i) {
                    final s = widget.slides[i] as Map<String, dynamic>;
                    final img = normalizeMediaUrl('${s['image_url'] ?? s['image'] ?? ''}');
                    final link = '${s['link_url'] ?? ''}';
                    return _SlideTapLayer(
                      onOpen: () => _openSlide(link),
                      child: img.isNotEmpty
                          ? ProgressiveNetworkImage(
                              imageUrl: img,
                              fit: BoxFit.cover,
                              placeholder: const ColoredBox(color: AppColors.bgDark),
                              errorWidget: const ColoredBox(color: AppColors.bgDark),
                            )
                          : const ColoredBox(color: AppColors.bgDark),
                    );
                  },
                ),
                if (n > 1) ...[
                  if (wide) ...[
                    Positioned(
                      left: navInset,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _SliderNavCircle(
                          size: navSize,
                          icon: Icons.chevron_left_rounded,
                          iconSize: navIcon,
                          background: navBg,
                          foreground: navFg,
                          shadow: dark ? const Color(0x73000000) : const Color(0x1F000000),
                          onTap: () => _goRelative(-1),
                          semanticLabel: 'Предыдущий слайд',
                        ),
                      ),
                    ),
                    Positioned(
                      right: navInset,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _SliderNavCircle(
                          size: navSize,
                          icon: Icons.chevron_right_rounded,
                          iconSize: navIcon,
                          background: navBg,
                          foreground: navFg,
                          shadow: dark ? const Color(0x73000000) : const Color(0x1F000000),
                          onTap: () => _goRelative(1),
                          semanticLabel: 'Следующий слайд',
                        ),
                      ),
                    ),
                  ],
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: dotsBottom,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < n; i++) ...[
                          if (i > 0) SizedBox(width: dotGap),
                          Semantics(
                            selected: i == _i,
                            label: 'Слайд ${i + 1}',
                            button: true,
                            child: GestureDetector(
                              onTap: () {
                                _controller.animateToPage(
                                  i,
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOut,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                width: i == _i ? dotActiveW : dotSize,
                                height: dotSize,
                                decoration: BoxDecoration(
                                  color: i == _i
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Тап бе монеа кардани swipe — фақат агар ангушт ҳаракат накунad.
class _SlideTapLayer extends StatefulWidget {
  const _SlideTapLayer({required this.child, required this.onOpen});

  final Widget child;
  final VoidCallback onOpen;

  @override
  State<_SlideTapLayer> createState() => _SlideTapLayerState();
}

class _SlideTapLayerState extends State<_SlideTapLayer> {
  Offset? _down;
  static const _tapSlop = 18.0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _down = e.position,
      onPointerMove: (e) {
        final start = _down;
        if (start == null) return;
        if ((e.position - start).distance > _tapSlop) {
          _down = null;
        }
      },
      onPointerUp: (e) {
        final start = _down;
        _down = null;
        if (start == null) return;
        if ((e.position - start).distance <= _tapSlop) {
          widget.onOpen();
        }
      },
      onPointerCancel: (_) => _down = null,
      child: widget.child,
    );
  }
}

class _SliderNavCircle extends StatelessWidget {
  const _SliderNavCircle({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.background,
    required this.foreground,
    required this.shadow,
    required this.onTap,
    required this.semanticLabel,
  });

  final double size;
  final IconData icon;
  final double iconSize;
  final Color background;
  final Color foreground;
  final Color shadow;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Semantics(
          label: semanticLabel,
          button: true,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              boxShadow: [
                BoxShadow(
                  color: shadow,
                  blurRadius: dark ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: iconSize, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// 2 сатр, як скрол; корт сафед — танҳо расм; паҳно аз нисбати аслии расм (баландӣ сатр яксон).
class _HomeFallbackBanner extends StatelessWidget {
  const _HomeFallbackBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 178,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3D7CFF), Color(0xFF005BFE)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: DastrassLogo(height: 56, maxWidth: 220),
          ),
        ),
      ),
    );
  }
}

class _HomeCategoryTwoRows extends StatelessWidget {
  const _HomeCategoryTwoRows({required this.categories});

  static const int _row1Count = 6;
  static const int _row2Max = 8;

  final List<dynamic> categories;

  @override
  Widget build(BuildContext context) {
    final items = categories.toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final row1 = items.take(_row1Count).toList();
    final row2 = items.skip(_row1Count).take(_row2Max).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeCategoryRow(items: row1, cardHeight: 110, compact: false),
        if (row2.isNotEmpty) ...[
          const SizedBox(height: 12),
          _HomeCategoryRow(items: row2, cardHeight: 94, compact: true),
        ],
      ],
    );
  }
}

class _HomeCategoryRow extends StatelessWidget {
  const _HomeCategoryRow({
    required this.items,
    required this.cardHeight,
    required this.compact,
  });

  final List<dynamic> items;
  final double cardHeight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: _HomeCategoryCell(
              category: items[i] as Map<String, dynamic>,
              imageHeight: cardHeight,
              compactName: compact,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryTwoRowStrip extends StatefulWidget {
  const _CategoryTwoRowStrip({required this.categories});
  final List<dynamic> categories;

  @override
  State<_CategoryTwoRowStrip> createState() => _CategoryTwoRowStripState();
}

class _CategoryTwoRowStripState extends State<_CategoryTwoRowStrip> {
  static const double _kCardH = 72;
  static const double _kRowGap = 8;
  static const double _kPillGap = 8;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) return const SizedBox.shrink();

    final row1 = widget.categories.take(6).toList();
    final row2 = widget.categories.length > 6 ? widget.categories.sublist(6) : <dynamic>[];
    const nameH = 18.0;
    final rowBlockH = _kCardH + 5 + nameH;
    final contentH = row2.isNotEmpty ? (rowBlockH + _kRowGap + rowBlockH) : rowBlockH;
    final cellW = (MediaQuery.sizeOf(context).width * 0.28).clamp(96.0, 112.0);

    return SizedBox(
      height: contentH,
      width: MediaQuery.sizeOf(context).width,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < row1.length; i++) ...[
                    if (i > 0) const SizedBox(width: _kPillGap),
                    _HomeCategoryCell(
                      category: row1[i] as Map<String, dynamic>,
                      imageHeight: _kCardH,
                      width: cellW,
                      compactName: true,
                    ),
                  ],
                ],
              ),
              if (row2.isNotEmpty) ...[
                const SizedBox(height: _kRowGap),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < row2.length; i++) ...[
                      if (i > 0) const SizedBox(width: _kPillGap),
                      _HomeCategoryCell(
                        category: row2[i] as Map<String, dynamic>,
                        imageHeight: _kCardH,
                        width: cellW,
                        compactName: true,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ячейка категории (мисли `.home-cat-cell` во фронтенде): фото/иконка + название.
class _HomeCategoryCell extends StatelessWidget {
  const _HomeCategoryCell({
    required this.category,
    this.imageHeight = 72,
    this.width,
    this.compactName = false,
  });

  final Map<String, dynamic> category;
  final double imageHeight;
  final double? width;
  final bool compactName;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final slug = '${category['slug'] ?? ''}';
    final name = '${category['name'] ?? ''}';
    final iconUrl = normalizeMediaUrl('${category['icon_url'] ?? ''}');
    final imgBg = light ? const Color(0xFFE9ECEF) : const Color(0xFF1A2235);
    final nameColor = light ? const Color(0xFF212529) : Theme.of(context).colorScheme.onSurface;
    final fallbackIcon = categoryIconForSlug(slug);

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: slug.isEmpty ? null : () => context.push('/ads?category=$slug'),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: imageHeight,
                  width: width ?? double.infinity,
                  child: ColoredBox(
                    color: imgBg,
                    child: iconUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: iconUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                            width: double.infinity,
                            height: imageHeight,
                            errorWidget: (_, _, _) => _CategoryIconFallback(icon: fallbackIcon),
                          )
                        : _CategoryIconFallback(icon: fallbackIcon),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compactName ? 10 : 12,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: nameColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIconFallback extends StatelessWidget {
  const _CategoryIconFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(icon, color: AppColors.primary, size: 28),
    );
  }
}
