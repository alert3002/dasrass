import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../services/favorites_service.dart';
import '../services/favorites_store.dart';
import '../theme/app_theme.dart';
import '../utils/ad_format.dart';
import '../utils/compare_fields.dart';
import '../utils/color_catalog.dart';
import '../utils/related_ads_query.dart';
import '../utils/passenger_car.dart';
import '../utils/time_ago.dart';
import '../utils/locality_label.dart';
import '../utils/network_error_message.dart';
import '../widgets/ad_listing_grid.dart';
import '../utils/share_text.dart';
import '../widgets/progressive_network_image.dart';
import '../widgets/report_block_sheet.dart';

class AdDetailScreen extends StatefulWidget {
  const AdDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  Map<String, dynamic>? _ad;
  List<Map<String, dynamic>> _related = [];
  bool _loading = true;
  String? _error;
  int _imgIndex = 0;
  bool _favBusy = false;
  bool _storyBusy = false;
  bool _authorAvatarErr = false;
  bool _freshLoaded = false;
  late final PageController _galleryPageController;

  @override
  void initState() {
    super.initState();
    _galleryPageController = PageController();
    unawaited(_ensureColors());
    unawaited(_hydrateFromCache());
    _load();
  }

  Future<void> _ensureColors() async {
    await ColorCatalog.instance.ensureLoaded();
    if (mounted) setState(() {});
  }

  Future<void> _hydrateFromCache() async {
    final cached = await DastrassApi.instance.cachedAdDetail(widget.id);
    if (cached == null || !mounted) return;
    await FavoritesStore.instance.hydrate();
    final idNum = int.tryParse('${cached['id']}') ?? 0;
    final guestFav = !AuthService.instance.isAuthenticated &&
        FavoritesStore.instance.contains(idNum);
    if (!mounted || _freshLoaded) return;
    setState(() {
      _ad = {
        ...cached,
        if (guestFav) 'is_favorite': true,
      };
      _loading = false;
      _error = null;
    });
    _prefetchAdImages(cached);
  }

  void _prefetchAdImages(Map<String, dynamic> ad) {
    final urls = <String>[];
    final thumb = resolveAdImageUrl(ad);
    if (thumb.isNotEmpty) urls.add(thumb);
    final images = ad['images'];
    if (images is List) {
      for (final item in images) {
        final u = normalizeMediaUrl('$item');
        if (u.isNotEmpty) urls.add(u);
      }
    }
    AdImagePrefetch.prefetchUrls(urls);
  }

  @override
  void dispose() {
    _galleryPageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hadCache = _ad != null;
    setState(() {
      _loading = !hadCache;
      _error = null;
    });
    try {
      final ad = await DastrassApi.instance.fetchAdDetailFresh(widget.id);
      if (!mounted) return;
      _freshLoaded = true;
      await FavoritesStore.instance.hydrate();
      final idNum = int.tryParse('${ad['id']}') ?? 0;
      final guestFav = !AuthService.instance.isAuthenticated &&
          FavoritesStore.instance.contains(idNum);
      setState(() {
        _ad = {
          ...ad,
          if (guestFav) 'is_favorite': true,
        };
        _imgIndex = 0;
        _authorAvatarErr = false;
        _loading = false;
      });
      if (_galleryPageController.hasClients) {
        _galleryPageController.jumpToPage(0);
      }
      _prefetchAdImages(ad);
      unawaited(_loadRelated(ad));
    } on ApiException catch (e) {
      if (mounted && _ad == null) setState(() => _error = e.message);
    } catch (e) {
      if (mounted && _ad == null) {
        setState(() => _error = friendlyErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRelated(Map<String, dynamic> ad) async {
    final levels = buildRelatedAdsQueryLevels(ad);
    final picked = <int, Map<String, dynamic>>{};

    Future<void> runPass({required bool strictBrand}) async {
      for (final params in levels) {
        try {
          final data = await DastrassApi.instance.ads(params);
          for (final row in data['results'] as List? ?? []) {
            final m = Map<String, dynamic>.from(row as Map);
            if (!isSimilarAdCandidate(ad, m, strictBrand: strictBrand)) continue;
            final id = int.tryParse('${m['id']}') ?? 0;
            if (id > 0) picked[id] = m;
          }
          if (picked.length >= 4) return;
        } catch (_) {}
      }
    }

    await runPass(strictBrand: true);
    if (picked.length < 4) await runPass(strictBrand: false);
    if (!mounted) return;
    final related = picked.values.take(4).toList();
    setState(() => _related = related);
    AdImagePrefetch.prefetchFromAds(related);
  }

  List<String> _images(Map<String, dynamic> ad) {
    final out = <String>[];
    if (ad['images'] is List) {
      for (final img in ad['images'] as List) {
        if (img is String && img.isNotEmpty) {
          final u = normalizeMediaUrl(img);
          if (u.isNotEmpty) out.add(u);
        } else if (img is Map) {
          final u = img['image_url'] ?? img['url'] ?? img['src'];
          final n = normalizeMediaUrl(u == null ? '' : '$u');
          if (n.isNotEmpty) out.add(n);
        }
      }
    }
    if (out.isEmpty) {
      final fallback = resolveAdImageUrl(ad);
      if (fallback.isNotEmpty) out.add(fallback);
    }
    return out;
  }

  String _createdLabel(Map<String, dynamic> ad) => formatTimeAgo('${ad['created_at'] ?? ''}');

  int _viewsCount(Map<String, dynamic> ad) {
    final v = ad['views_count'];
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  Future<void> _toggleFavorite() async {
    setState(() => _favBusy = true);
    try {
      final res = await FavoritesService.toggle(widget.id);
      final fav = res['is_favorite'];
      if (fav is bool && mounted) {
        setState(() => _ad = {...?_ad, 'is_favorite': fav});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fav ? 'Добавлено в избранное' : 'Удалено из избранного')),
        );
      } else {
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }

  Future<void> _requestStory() async {
    if (!AuthService.instance.isAuthenticated) {
      context.push('/login?redirect=${Uri.encodeComponent('/ads/${widget.id}')}');
      return;
    }
    setState(() => _storyBusy = true);
    try {
      final res = await DastrassApi.instance.requestStory(widget.id);
      if (!mounted) return;
      final msg = '${res['message'] ?? 'Заявка отправлена'}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _storyBusy = false);
    }
  }

  Future<void> _openMessage(Map<String, dynamic> ad) async {
    if (!AuthService.instance.isAuthenticated) {
      context.push('/login?redirect=${Uri.encodeComponent('/ads/${widget.id}')}');
      return;
    }
    final phone = '${ad['phone'] ?? ''}'.trim();
    final title = '${ad['title'] ?? 'Объявление'}';
    final input = TextEditingController(text: 'Здравствуйте!');
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Сообщение продавцу', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Текст сообщения'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Отправить'),
              ),
            ],
          ),
        );
      },
    );
    if (sent != true || !mounted) {
      input.dispose();
      return;
    }
    final text = input.text.trim();
    input.dispose();
    if (text.isEmpty) return;
    try {
      final res = await DastrassApi.instance.messageSend(
        text: text,
        vehicleId: int.tryParse(widget.id),
        toPhone: phone.isNotEmpty ? phone : null,
      );
      if (!mounted) return;
      final cid = res['conversation_id'];
      if (cid != null) {
        context.push(
          '/messages/chat/$cid',
          extra: {'title': title, 'sub': phone},
        );
      } else {
        context.go('/messages');
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final onBg = theme.colorScheme.onSurface;
    final muted = theme.hintColor;
    final panelHeadBg = dark ? const Color(0xFF1A2230) : const Color(0xFFF1F3F5);

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _ad == null
                  ? const Center(child: Text('Объявление не найдено.'))
                  : SafeArea(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 32),
                          children: [
                            _buildTopBar(_ad!, muted),
                            _buildMockupGallery(_ad!, muted),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHeadRow(_ad!, onBg, muted),
                                  const SizedBox(height: 10),
                                  _buildPriceCityRow(_ad!, onBg),
                                  const SizedBox(height: 14),
                                  _buildSpecsSection(_ad!, onBg, muted, panelHeadBg),
                                  const SizedBox(height: 14),
                                  _buildDescriptionSection(_ad!, onBg, muted, panelHeadBg),
                                  const SizedBox(height: 14),
                                  _buildSellerSection(
                                    _ad!,
                                    onBg: onBg,
                                    muted: muted,
                                    panelHeadBg: panelHeadBg,
                                    onMessage: () => _openMessage(_ad!),
                                    onAuthorAvatarError: () => setState(() => _authorAvatarErr = true),
                                  ),
                                  if (_related.isNotEmpty) ...[
                                    const SizedBox(height: 18),
                                    Text(
                                      'Похожие',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: onBg,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    AdListingGrid(
                                      ads: _related,
                                      shrinkWrap: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildTopBar(Map<String, dynamic> ad, Color muted) {
    final isFav = ad['is_favorite'] == true;
    final isMine = ad['is_mine'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          if (isMine)
            TextButton(
              onPressed: _storyBusy ? null : _requestStory,
              child: _storyBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('История'),
            ),
          IconButton(
            onPressed: _favBusy ? null : _toggleFavorite,
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? AppColors.primary : muted,
            ),
          ),
          Builder(
            builder: (shareCtx) => IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () async {
                final url = '${ApiConfig.publicSiteOrigin}/ads/${ad['id']}';
                await shareTextFromContext(shareCtx, '${ad['title'] ?? ''}\n$url');
              },
            ),
          ),
          if (!isMine)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => showReportBlockSheet(
                context,
                adId: '${ad['id']}',
                sellerPhone: '${ad['phone'] ?? ''}',
                onBlocked: () => context.pop(),
              ),
            ),
        ],
      ),
    );
  }

  void _openGalleryViewer(List<String> images, int index, String title) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _AdImageViewerPage(
          images: images,
          initialIndex: index,
          title: title,
        ),
      ),
    );
  }

  void _openVideoFullscreen(String url) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _AdVideoFullscreenPage(url: url),
      ),
    );
  }

  Widget _buildMockupGallery(Map<String, dynamic> ad, Color muted) {
    final images = _images(ad);
    final videoUrl = normalizeMediaUrl('${ad['video_url'] ?? ''}');
    final hasVideo = videoUrl.isNotEmpty;
    final slideCount = images.length + (hasVideo ? 1 : 0);
    final videoSlideIndex = hasVideo ? images.length : -1;

    if (slideCount == 0) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: adGalleryPhotoBg(context),
          child: Center(
            child: Text('Нет фото', style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    final title = '${ad['title'] ?? ''}';
    final maxGalleryH = MediaQuery.sizeOf(context).height * 0.55;
    return SizedBox(
      width: double.infinity,
      height: maxGalleryH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _galleryPageController,
            itemCount: slideCount,
            onPageChanged: (i) => setState(() => _imgIndex = i),
            itemBuilder: (context, i) {
              if (hasVideo && i == videoSlideIndex) {
                return _GalleryInlineVideo(
                  url: videoUrl,
                  isActive: _imgIndex == videoSlideIndex,
                  muted: muted,
                  onFullscreen: () => _openVideoFullscreen(videoUrl),
                );
              }

              final url = images[i];
              return GestureDetector(
                onTap: () => _openGalleryViewer(images, i, title),
                child: AdGalleryImage(
                  imageUrl: url,
                  width: double.infinity,
                  backgroundColor: adGalleryPhotoBg(context),
                  errorChild: Center(
                    child: Text(
                      'Фото недоступно',
                      style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              );
            },
          ),
          if (slideCount > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GalleryArrow(
                  label: '‹',
                  onTap: () {
                    final prev = _imgIndex == 0 ? slideCount - 1 : _imgIndex - 1;
                    _galleryPageController.animateToPage(
                      prev,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GalleryArrow(
                  label: '›',
                  onTap: () {
                    final next = _imgIndex >= slideCount - 1 ? 0 : _imgIndex + 1;
                    _galleryPageController.animateToPage(
                      next,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slideCount, (i) {
                  final active = i == _imgIndex;
                  return GestureDetector(
                    onTap: () => _galleryPageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                    child: Container(
                      width: active ? 8 : 6,
                      height: active ? 8 : 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? Colors.white : Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeadRow(Map<String, dynamic> ad, Color onBg, Color muted) {
    final title = '${ad['title'] ?? ''}';
    final created = _createdLabel(ad);
    final views = _viewsCount(ad);
    final adId = '${ad['id'] ?? widget.id}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3, color: onBg),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (created.isNotEmpty)
              Text(created, style: TextStyle(fontSize: 11, color: muted)),
            Text('# $adId', style: TextStyle(fontSize: 11, color: muted)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.remove_red_eye_outlined, size: 13, color: muted),
                const SizedBox(width: 3),
                Text('$views', style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceCityRow(Map<String, dynamic> ad, Color onBg) {
    final city = _shortCityLabel(ad);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          formatAdListingPrice(ad['price'], '${ad['currency'] ?? ''}', homeStyle: true),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: onBg,
          ),
        ),
        if (city.isNotEmpty)
          Text(
            city,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onBg),
          ),
      ],
    );
  }

  String _shortCityLabel(Map<String, dynamic> ad) {
    return shortLocalityLabel('${ad['location'] ?? ''}');
  }

  Widget _buildSpecsSection(
    Map<String, dynamic> ad,
    Color onBg,
    Color muted,
    Color panelBg,
  ) {
    final specs = getAdDetailSpecs(ad);
    if (specs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Характеристика', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (var i = 0; i < specs.length; i++) ...[
                if (i > 0) Divider(height: 1, color: muted.withValues(alpha: 0.25)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          specs[i].label,
                          style: TextStyle(fontSize: 14, color: muted, height: 1.35),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          specs[i].value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: onBg,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(
    Map<String, dynamic> ad,
    Color onBg,
    Color muted,
    Color panelBg,
  ) {
    final desc = stripBodyTypeFromDescription('${ad['description'] ?? ''}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Описание', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            desc.isEmpty ? 'Описание не указано' : desc,
            style: TextStyle(
              height: 1.55,
              color: desc.isEmpty ? muted : onBg,
              fontStyle: desc.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSellerSection(
    Map<String, dynamic> ad, {
    required Color onBg,
    required Color muted,
    required Color panelHeadBg,
    required VoidCallback onMessage,
    required VoidCallback onAuthorAvatarError,
  }) {
    final phone = '${ad['phone'] ?? ''}'.trim();
    final authorName = _authorDisplayName(ad);
    final avatar = normalizeMediaUrl('${ad['seller_avatar_url'] ?? ''}');
    final phoneLabel = _formatPhoneDisplay(phone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar.isNotEmpty && !_authorAvatarErr
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => onAuthorAvatarError());
                        return _sellerAvatarFallback(authorName, '${ad['phone'] ?? ''}');
                      },
                    )
                  : _sellerAvatarFallback(authorName, '${ad['phone'] ?? ''}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName.isEmpty ? 'Продавец' : authorName,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: onBg),
                  ),
                  if (phone.isNotEmpty)
                    TextButton(
                      onPressed: () => context.push('/ads?phone=${Uri.encodeComponent(phone)}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Все объявления автора'),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: phone.isNotEmpty
                  ? OutlinedButton(
                      onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: panelHeadBg,
                        side: BorderSide(color: muted.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        phoneLabel.isEmpty ? phone : phoneLabel,
                        style: TextStyle(fontWeight: FontWeight.w700, color: onBg),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: null,
                      child: const Text('Нет телефона'),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onMessage,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Написать'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatPhoneDisplay(String phone) {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('992')) d = d.substring(3);
    if (d.length >= 9) {
      return '${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5, 7)} ${d.substring(7, 9)}';
    }
    return phone;
  }

  static String _authorDisplayName(Map<String, dynamic> ad) {
    final raw = '${ad['seller_name'] ?? ''}'.trim();
    if (raw.isEmpty || raw == 'Автор объявления') return '';
    return raw;
  }

  static String _authorInitials(String name, String phone) {
    final n = name.trim();
    if (n.isNotEmpty) {
      final p = n.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final a = p.isNotEmpty ? p.first[0] : '';
      final b = p.length > 1 ? p.last[0] : '';
      final s = '$a$b'.trim();
      if (s.isNotEmpty) return s.toUpperCase();
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2).toUpperCase();
    return '?';
  }

  Widget _sellerAvatarFallback(String name, String phone) {
    return Center(
      child: Text(
        _authorInitials(name, phone),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

}

class _AdImageViewerPage extends StatefulWidget {
  const _AdImageViewerPage({
    required this.images,
    required this.initialIndex,
    required this.title,
  });

  final List<String> images;
  final int initialIndex;
  final String title;

  @override
  State<_AdImageViewerPage> createState() => _AdImageViewerPageState();
}

class _AdImageViewerPageState extends State<_AdImageViewerPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int delta) {
    if (widget.images.length <= 1) return;
    final next = _index + delta;
    if (next < 0 || next >= widget.images.length) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoBg = adGalleryPhotoBg(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onPhotoBg = isDark ? Colors.white : AppColors.textLight;
    final progressTrack = isDark ? Colors.white24 : Colors.black26;
    final progressFill = isDark ? Colors.white : AppColors.textLight;

    return Scaffold(
      backgroundColor: photoBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: List.generate(widget.images.length, (i) {
                  final fill = i <= _index ? 1.0 : 0.0;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: progressTrack,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fill,
                        child: Container(
                          decoration: BoxDecoration(
                            color: progressFill,
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
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onPhotoBg,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    icon: Icon(Icons.close_rounded, color: onPhotoBg),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      return InteractiveViewer(
                        minScale: 1,
                        maxScale: 3,
                        child: AdGalleryImage(
                          imageUrl: widget.images[i],
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                  if (widget.images.length > 1)
                    Positioned.fill(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _go(-1),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _go(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryArrow extends StatelessWidget {
  const _GalleryArrow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(side: BorderSide(color: Color(0xFFDDDDDD))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(label, style: const TextStyle(fontSize: 28, height: 1)),
          ),
        ),
      ),
    );
  }
}

class _GalleryPlayButton extends StatelessWidget {
  const _GalleryPlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
          ),
        ),
      ),
    );
  }
}

/// Видео дар ҳамон слайди галерея — бе такрори аввалин сурат.
class _GalleryInlineVideo extends StatefulWidget {
  const _GalleryInlineVideo({
    required this.url,
    required this.isActive,
    required this.muted,
    required this.onFullscreen,
  });

  final String url;
  final bool isActive;
  final Color muted;
  final VoidCallback onFullscreen;

  @override
  State<_GalleryInlineVideo> createState() => _GalleryInlineVideoState();
}

class _GalleryInlineVideoState extends State<_GalleryInlineVideo> with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _playing = false;
  bool _waitingPlay = false;
  bool _initStarted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _ensureInit();
  }

  Future<void> _ensureInit() async {
    if (_initStarted) return;
    _initStarted = true;
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    try {
      await c.initialize();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _GalleryInlineVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_initStarted) {
      unawaited(_ensureInit());
    }
    if (!widget.isActive && _playing) {
      _controller?.pause();
      setState(() => _playing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onPlay() async {
    if (_waitingPlay) return;
    if (!_initStarted) {
      setState(() => _waitingPlay = true);
      await _ensureInit();
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      if (mounted) setState(() => _waitingPlay = false);
      return;
    }
    await c.play();
    if (mounted) {
      setState(() {
        _playing = true;
        _waitingPlay = false;
      });
    }
  }

  Widget _videoPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? const Color(0xFF12141A) : const Color(0xFF1A1F28),
      child: Center(
        child: Icon(
          Icons.videocam_rounded,
          size: 44,
          color: widget.muted.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _smallLoader() {
    return const SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        color: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = _controller;
    final ready = c != null && c.value.isInitialized;

    return ColoredBox(
      color: _playing ? Colors.black : adGalleryPhotoBg(context),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (_playing && ready)
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
            )
          else if (ready)
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
            )
          else
            _videoPlaceholder(),
          if (!_playing)
            if (_waitingPlay)
              _smallLoader()
            else
              _GalleryPlayButton(onTap: _onPlay),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: Material(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: widget.onFullscreen,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Полный экран',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdVideoFullscreenPage extends StatefulWidget {
  const _AdVideoFullscreenPage({required this.url});

  final String url;

  @override
  State<_AdVideoFullscreenPage> createState() => _AdVideoFullscreenPageState();
}

class _AdVideoFullscreenPageState extends State<_AdVideoFullscreenPage> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    try {
      await c.initialize();
      await c.play();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              ),
            ),
            if (ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.primary,
                      bufferedColor: Color(0x66FFFFFF),
                      backgroundColor: Color(0x33FFFFFF),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
