import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../services/favorites_service.dart';
import '../services/favorites_store.dart';
import '../theme/app_theme.dart';
import '../utils/ad_format.dart';
import '../utils/locality_label.dart';
import '../utils/time_ago.dart';
import 'ad_listing_layout.dart';
import 'ad_no_photo_placeholder.dart';
import 'progressive_network_image.dart';

export '../utils/ad_format.dart' show formatAdListingPrice, resolveAdImageUrl;

/// Карточка объявления в сетке — макет «Рекомендация» (главная, категории, похожие).
class DastrassAdListingCard extends StatefulWidget {
  const DastrassAdListingCard({
    super.key,
    required this.ad,
    required this.mediaHeight,
    required this.bodyHeight,
    this.favoritesListMode = false,
    this.onRemovedFromFavorites,
  });

  final Map<String, dynamic> ad;
  final double mediaHeight;
  final double bodyHeight;
  /// Дар `/favorites`: дил даста шудани API [toggleFavorite] → `is_favorite: false`.
  final bool favoritesListMode;
  final VoidCallback? onRemovedFromFavorites;

  @override
  State<DastrassAdListingCard> createState() => _DastrassAdListingCardState();
}

class _DastrassAdListingCardState extends State<DastrassAdListingCard> {
  bool _favBusy = false;

  Map<String, dynamic> get _a => widget.ad;

  void _openAd() {
    final id = '${_a['id'] ?? ''}';
    if (id.isNotEmpty) context.push('/ads/$id');
  }

  Future<void> _onFavorite() async {
    final id = '${_a['id'] ?? ''}';
    if (id.isEmpty) return;
    setState(() => _favBusy = true);
    try {
      final res = await FavoritesService.toggle(id);
      final ok = res['ok'] == true;
      final fav = res['is_favorite'];
      if (ok && fav is bool && mounted) {
        if (widget.favoritesListMode && !fav) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Удалено из избранного')),
          );
          widget.onRemovedFromFavorites?.call();
          return;
        }
        setState(() => _a['is_favorite'] = fav);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fav ? 'Добавлено в избранное' : 'Удалено из избранного')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final dark = theme.brightness == Brightness.dark;
    final cardBg = dark ? AppColors.cardDark : Colors.white;
    final titleCol = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).hintColor;

    final id = '${_a['id'] ?? ''}';
    final title = '${_a['title'] ?? 'Без названия'}';
    final priceLabel = formatAdListingPrice(
      _a['price'],
      '${_a['currency'] ?? ''}',
      homeStyle: true,
    );
    final locRaw = '${_a['location'] ?? ''}'.trim();
    final loc = shortLocalityLabel(locRaw);
    final timeAgo = formatTimeAgo('${_a['created_at'] ?? ''}');
    final img = resolveAdImageUrl(_a);
    final isTop = _a['is_top'] == true;
    final idNum = int.tryParse(id) ?? 0;
    final fav = widget.favoritesListMode ||
        _a['is_favorite'] == true ||
        (!AuthService.instance.isAuthenticated && FavoritesStore.instance.contains(idNum));

    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.mediaHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: _openAd,
                  child: img.isNotEmpty
                      ? AdListingImage(
                          imageUrl: img,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : const AdNoPhotoPlaceholder.expand(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _AdCircleBtn(
                    onTap: _favBusy ? null : _onFavorite,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 22,
                      color: fav ? AppColors.primary : const Color(0xFF6C757D),
                    ),
                  ),
                ),
                if (isTop)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          '✓ ТОП',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: widget.bodyHeight,
            child: GestureDetector(
              onTap: _openAd,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AdListingCardLayout.bodyPaddingH,
                  AdListingCardLayout.bodyPaddingTop,
                  AdListingCardLayout.bodyPaddingH,
                  AdListingCardLayout.bodyPaddingBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: AdListingCardLayout.titleBlockHeight,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.25,
                            color: titleCol,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AdListingCardLayout.gapAfterTitle),
                    SizedBox(
                      height: AdListingCardLayout.priceBlockHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          priceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            color: titleCol,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AdListingCardLayout.gapAfterPrice),
                    SizedBox(
                      height: AdListingCardLayout.locationBlockHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          loc.isNotEmpty ? loc : ' ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: muted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AdListingCardLayout.gapAfterLocation),
                    SizedBox(
                      height: AdListingCardLayout.timeBlockHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          timeAgo.isNotEmpty ? timeAgo : ' ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: muted,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdCircleBtn extends StatelessWidget {
  const _AdCircleBtn({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(child: child),
        ),
      ),
    );
  }
}
