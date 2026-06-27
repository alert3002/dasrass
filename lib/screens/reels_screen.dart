import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../services/favorites_service.dart';
import '../services/favorites_store.dart';
import '../services/reels_video_cache.dart';
import '../theme/app_theme.dart';
import '../utils/locality_label.dart';
import '../utils/network_error_message.dart';
import '../utils/reels_feed_cache.dart';
import '../utils/reels_feed_reload.dart';
import '../utils/ad_format.dart';
import '../utils/share_text.dart';
import '../widgets/dastrass_app_drawer.dart';

/// Лента Reels
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelAd {
  _ReelAd({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.imageUrl,
    this.location,
    this.price,
    this.currency,
    required this.isFavorite,
  });

  final int id;
  final String title;
  final String videoUrl;
  final String? imageUrl;
  final String? location;
  final dynamic price;
  final String? currency;
  bool isFavorite;

  static _ReelAd? tryParse(Map<String, dynamic> m) {
    final idRaw = m['id'];
    final v = normalizeMediaUrl(m['video_url'] as String?);
    if (idRaw == null || v.isEmpty) return null;
    final titleRaw = (m['title'] as String?)?.trim();
    final locRaw = (m['location'] as String?)?.trim();
    final id = int.tryParse('$idRaw') ?? 0;
    final poster = normalizeMediaUrl(m['image_url'] as String?);
    return _ReelAd(
      id: id,
      title: (titleRaw != null && titleRaw.isNotEmpty) ? titleRaw : 'Объявление',
      videoUrl: v,
      imageUrl: poster.isEmpty ? null : poster,
      location: (locRaw != null && locRaw.isNotEmpty) ? locRaw : null,
      price: m['price'],
      currency: m['currency'] as String?,
      isFavorite: m['is_favorite'] == true ||
          (!AuthService.instance.isAuthenticated && FavoritesStore.instance.contains(id)),
    );
  }
}

class _ReelsScreenState extends State<ReelsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _pageController = PageController();

  List<_ReelAd> _ads = [];
  bool _loading = true;
  String? _loadError;
  bool _internetUnavailable = false;

  final Map<int, VideoPlayerController> _controllers = {};
  int _current = 0;
  int? _favBusyId;

  static const _textShadowStrong = [
    Shadow(color: Color(0xE6000000), blurRadius: 8, offset: Offset(0, 1)),
  ];
  static const _textShadowCity = [
    Shadow(color: Color(0xD9000000), blurRadius: 6, offset: Offset(0, 1)),
  ];

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuth);
    ReelsFeedReload.instance.tick.addListener(_onReelsReloadTick);
    _pageController.addListener(_onPageScroll);
    _loadAds();
  }

  void _onReelsReloadTick() {
    if (!mounted) return;
    _reloadFeed();
  }

  Future<void> _reloadFeed() async {
    for (final c in _controllers.values) {
      await c.dispose();
    }
    _controllers.clear();
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    setState(() => _current = 0);
    await _loadAds(forceRefresh: true);
  }

  @override
  void dispose() {
    ReelsFeedReload.instance.tick.removeListener(_onReelsReloadTick);
    AuthService.instance.removeListener(_onAuth);
    _pageController.removeListener(_onPageScroll);
    for (final c in _controllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (!_pageController.hasClients || _ads.isEmpty) return;
    final page = _pageController.page;
    if (page == null) return;
    final index = page.round().clamp(0, _ads.length - 1);
    final settled = (page - index).abs() < 0.01;
    if (!settled) {
      _pauseAllVideos();
      return;
    }
    if (index == _current) {
      unawaited(_playOnly(index));
    }
  }

  void _pauseAllVideos() {
    for (final c in _controllers.values) {
      if (!c.value.isInitialized) continue;
      c.pause();
      c.setVolume(0);
    }
  }

  Future<void> _playOnly(int index) async {
    for (final e in _controllers.entries) {
      final c = e.value;
      if (!c.value.isInitialized || c.value.hasError) continue;
      if (e.key == index) {
        await c.setVolume(1.0);
        await c.play();
      } else {
        await c.pause();
        await c.setVolume(0);
      }
    }
  }

  void _prefetchVideosAround(int center) {
    for (var i = center + 1; i <= center + 2 && i < _ads.length; i++) {
      ReelsVideoCache.instance.prefetch(_ads[i].videoUrl);
    }
  }

  void _preloadControllersAround(int center) {
    for (var offset = 1; offset <= 1; offset++) {
      final i = center + offset;
      if (i < 0 || i >= _ads.length) continue;
      unawaited(_ensureVideo(i));
    }
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  bool _isConnectivityError(Object e) => isConnectivityError(e);

  String _friendlyLoadError(Object e) {
    if (_isConnectivityError(e)) {
      _internetUnavailable = true;
    }
    return friendlyLoadErrorMessage(e);
  }

  List<_ReelAd> _parseAds(Iterable<Map<String, dynamic>> raw) {
    final list = <_ReelAd>[];
    for (final e in raw) {
      final ad = _ReelAd.tryParse(e);
      if (ad != null) list.add(ad);
    }
    return list;
  }

  void _applyAds(List<_ReelAd> ads) {
    _ads = ads;
    _loading = false;
    _loadError = null;
  }

  Future<void> _startCurrentVideo() async {
    if (_ads.isEmpty || !mounted) return;
    final index = _current;
    unawaited(_ensureVideo(index, priority: true));
    await _playOnly(index);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _ads.isEmpty) return;
      unawaited(_playOnly(_current));
      _prefetchVideosAround(_current);
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (!mounted || _current != index) return;
        _preloadControllersAround(index);
      });
    });
  }

  Future<void> _loadAds({bool forceRefresh = false}) async {
    final cached = ReelsFeedCache.instance;
    if (!forceRefresh && cached.hasItems) {
      final ads = _parseAds(cached.shuffledItems());
      if (ads.isNotEmpty && mounted) {
        setState(() => _applyAds(ads));
        unawaited(_startCurrentVideo());
        if (!cached.isFresh) {
          unawaited(_refreshAdsInBackground());
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
        _internetUnavailable = false;
      });
    }

    try {
      final dataFuture = DastrassApi.instance.ads({
        'limit': '40',
        'shuffle': '1',
        'reels': '1',
      });
      await FavoritesStore.instance.hydrate();
      final data = await dataFuture;
      final raw = (data['results'] as List<dynamic>?) ?? [];
      final maps = <Map<String, dynamic>>[];
      for (final e in raw) {
        if (e is! Map) continue;
        maps.add(Map<String, dynamic>.from(e));
      }
      cached.store(maps);
      final shuffled = _parseAds(cached.shuffledItems());
      if (!mounted) return;
      setState(() => _applyAds(shuffled));
      if (shuffled.isNotEmpty) {
        await _startCurrentVideo();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = _friendlyLoadError(e);
      setState(() {
        _loading = false;
        _loadError = msg;
      });
    }
  }

  Future<void> _refreshAdsInBackground() async {
    try {
      await ReelsFeedCache.instance.refresh(force: true);
      if (!mounted || !ReelsFeedCache.instance.hasItems) return;
      final fresh = _parseAds(ReelsFeedCache.instance.shuffledItems());
      if (fresh.isEmpty) return;
      setState(() => _applyAds(fresh));
    } catch (_) {}
  }

  Future<VideoPlayerController?> _openController(String url, {required bool streamFirst}) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (streamFirst) {
      final cached = await ReelsVideoCache.instance
          .getCachedFile(url)
          .timeout(const Duration(milliseconds: 120), onTimeout: () => null);
      if (cached != null) {
        final fileCtrl = VideoPlayerController.file(cached);
        try {
          await fileCtrl.initialize();
          return fileCtrl;
        } catch (_) {
          await fileCtrl.dispose();
        }
      }
      final net = VideoPlayerController.networkUrl(uri);
      await net.initialize();
      Future<void>.delayed(const Duration(seconds: 2), () {
        ReelsVideoCache.instance.prefetch(url);
      });
      return net;
    }

    final cached = await ReelsVideoCache.instance.getCachedFile(url);
    if (cached != null) {
      final fileCtrl = VideoPlayerController.file(cached);
      try {
        await fileCtrl.initialize();
        return fileCtrl;
      } catch (_) {
        await fileCtrl.dispose();
      }
    }
    final net = VideoPlayerController.networkUrl(uri);
    await net.initialize();
    ReelsVideoCache.instance.prefetch(url);
    return net;
  }

  Future<void> _ensureVideo(int index, {bool priority = false}) async {
    if (index < 0 || index >= _ads.length) return;
    if (_controllers.containsKey(index)) {
      final c = _controllers[index]!;
      if (c.value.hasError) return;
      if (index == _current && c.value.isInitialized) {
        await _playOnly(index);
      }
      return;
    }
    final url = _ads[index].videoUrl;
    final isCurrent = index == _current;
    final streamFirst = priority || isCurrent;

    try {
      final c = await _openController(url, streamFirst: streamFirst);
      if (c == null || !mounted) {
        await c?.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(index == _current ? 1.0 : 0.0);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controllers[index] = c);
      if (index == _current) {
        await c.play();
      }
    } catch (_) {}
  }

  void _pruneVideos(int center) {
    for (final k in _controllers.keys.toList()) {
      if ((k - center).abs() > 2) {
        _controllers.remove(k)?.dispose();
      }
    }
  }

  Future<void> _onPageChanged(int index) async {
    _pauseAllVideos();
    setState(() => _current = index);
    _pruneVideos(index);
    await _ensureVideo(index, priority: true);
    await _playOnly(index);
    _prefetchVideosAround(index);
    Future<void>.delayed(const Duration(seconds: 1), () {
        if (!mounted || _current != index) return;
        _preloadControllersAround(index);
      });
    if (mounted) setState(() {});
  }

  void _toggleMute(VideoPlayerController? c) {
    if (c == null || !c.value.isInitialized) return;
    final muted = c.value.volume == 0;
    c.setVolume(muted ? 1.0 : 0);
    setState(() {});
  }

  Future<void> _toggleFavorite(_ReelAd ad) async {
    setState(() => _favBusyId = ad.id);
    try {
      final res = await FavoritesService.toggle('${ad.id}');
      final ok = res['ok'] == true;
      final fav = res['is_favorite'];
      if (ok && fav is bool && mounted) {
        setState(() => ad.isFavorite = fav);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fav ? 'Объявление в избранном' : 'Убрано из избранного')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _favBusyId = null);
    }
  }

  Future<void> _share(BuildContext anchorContext, _ReelAd ad) async {
    final url = '${ApiConfig.publicSiteOrigin}/ads/${ad.id}';
    final title = ad.title;
    try {
      await shareTextFromContext(anchorContext, '$title\n$url', subject: title);
    } catch (_) {
      await _copyLink(ad);
    }
  }

  Future<void> _copyLink(_ReelAd ad) async {
    final url = '${ApiConfig.publicSiteOrigin}/ads/${ad.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка на объявление скопирована')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: light ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFF0A0A0B),
      drawer: const DastrassAppDrawer(),
      extendBody: true,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_loadError != null) {
      final light = Theme.of(context).brightness == Brightness.light;
      final onBg = Theme.of(context).colorScheme.onSurface;
      final muted = Theme.of(context).hintColor;
      if (_internetUnavailable) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
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
                    style: TextStyle(height: 1.35, color: muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loadAds,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Не удалось загрузить Reels.\n$_loadError',
            textAlign: TextAlign.center,
            style: TextStyle(color: light ? onBg.withValues(alpha: 0.75) : const Color(0x8CFFFFFF)),
          ),
        ),
      );
    }
    if (_ads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Пока нет объявлений с видео.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0x8CFFFFFF),
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/ads'),
                child: const Text(
                  'К объявлениям',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _ads.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final ad = _ads[index];
        final vc = _controllers[index];
        return _ReelSlide(
          ad: ad,
          controller: vc,
          isActive: index == _current,
          favBusy: _favBusyId == ad.id,
          onToggleMute: () => _toggleMute(vc),
          onFavorite: () => _toggleFavorite(ad),
          onShare: (ctx) => _share(ctx, ad),
          onCopyLink: () => _copyLink(ad),
          onOpenAd: () {
            vc?.pause();
            context.push('/ads/${ad.id}');
          },
        );
      },
    );
  }
}

class _ReelSlide extends StatelessWidget {
  const _ReelSlide({
    required this.ad,
    required this.controller,
    required this.isActive,
    required this.favBusy,
    required this.onToggleMute,
    required this.onFavorite,
    required this.onShare,
    required this.onCopyLink,
    required this.onOpenAd,
  });

  final _ReelAd ad;
  final VideoPlayerController? controller;
  final bool isActive;
  final bool favBusy;
  final VoidCallback onToggleMute;
  final VoidCallback onFavorite;
  final void Function(BuildContext context) onShare;
  final VoidCallback onCopyLink;
  final VoidCallback onOpenAd;

  static String _shortCity(String? location) => shortLocalityLabel(location);

  static const _shade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x66000000),
      Color(0x00000000),
      Color(0x00000000),
      Color(0x9E000000),
    ],
    stops: [0, 0.26, 0.52, 1],
  );

  @override
  Widget build(BuildContext context) {
    final city = _shortCity(ad.location);
    final priceLabel = formatAdListingPrice(ad.price, ad.currency ?? '');
    const bottomGap = 6.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onToggleMute,
          behavior: HitTestBehavior.opaque,
          child: _buildVideoLayer(context),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: _shade),
          ),
        ),
        Positioned(
          right: 10,
          bottom: bottomGap + 98,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReelIconBtn(
                icon: ad.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: ad.isFavorite ? const Color(0xFFFF3040) : Colors.white,
                busy: favBusy,
                onTap: onFavorite,
              ),
              const SizedBox(height: 18),
              Builder(
                builder: (shareCtx) => _ReelIconBtn(
                  icon: Icons.share_rounded,
                  color: Colors.white,
                  busy: false,
                  onTap: () => onShare(shareCtx),
                ),
              ),
              const SizedBox(height: 18),
              _ReelIconBtn(
                icon: Icons.link_rounded,
                color: Colors.white,
                busy: false,
                onTap: onCopyLink,
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 58,
          bottom: bottomGap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      priceLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16.8,
                        height: 1.2,
                        shadows: _ReelsScreenState._textShadowStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ad.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.08,
                        height: 1.3,
                        shadows: _ReelsScreenState._textShadowStrong,
                      ),
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        city,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.8,
                          height: 1.2,
                          shadows: _ReelsScreenState._textShadowCity,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onOpenAd,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xE0FFFFFF), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Подробнее',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoLayer(BuildContext context) {
    final c = controller;
    final poster = ad.imageUrl;

    if (c == null) {
      return _posterOrPlaceholder(poster);
    }

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final ready = c.value.isInitialized && !c.value.hasError;
        final showFrame = ready;

        return ColoredBox(
          color: const Color(0xFF0A0A0B),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!showFrame) _posterOrPlaceholder(poster),
              if (showFrame)
                FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              if (!ready)
                const Align(
                  alignment: Alignment(0, -0.15),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _posterOrPlaceholder(String? posterUrl) {
    if (posterUrl != null && posterUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: posterUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, _) => const ColoredBox(color: Color(0xFF0A0A0B)),
        errorWidget: (context, _, error) => const ColoredBox(color: Color(0xFF0A0A0B)),
      );
    }
    return const ColoredBox(color: Color(0xFF0A0A0B));
  }
}

class _ReelIconBtn extends StatelessWidget {
  const _ReelIconBtn({
    required this.icon,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: busy
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 28, color: color),
        ),
      ),
    );
  }
}
