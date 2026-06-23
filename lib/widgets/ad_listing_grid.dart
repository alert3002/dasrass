import 'package:flutter/material.dart';

import 'ad_listing_layout.dart';
import 'dastrass_ad_listing_card.dart';

/// Параметры сетки объявлений (2 колонки, как «Рекомендация» на главной).
class AdListingGridMetrics {
  const AdListingGridMetrics({
    required this.gap,
    required this.cellWidth,
    required this.mediaHeight,
    required this.bodyHeight,
    required this.tileHeight,
  });

  static const double defaultGap = AdListingCardLayout.gridGap;
  static const double defaultBodyHeight = AdListingCardLayout.bodyHeight;

  final double gap;
  final double cellWidth;
  final double mediaHeight;
  final double bodyHeight;
  final double tileHeight;

  factory AdListingGridMetrics.forWidth(double width, {int columns = 2}) {
    const gap = defaultGap;
    const bodyHeight = defaultBodyHeight;
    final cellW = (width - gap * (columns - 1)) / columns;
    return AdListingGridMetrics(
      gap: gap,
      cellWidth: cellW,
      mediaHeight: cellW,
      bodyHeight: bodyHeight,
      tileHeight: cellW + bodyHeight,
    );
  }

  /// Одна карточка на всю ширину (поиск, автор, телефон).
  factory AdListingGridMetrics.forFullWidth(double width) {
    const gap = defaultGap;
    const bodyHeight = defaultBodyHeight;
    final mediaHeight = (width * 10 / 16).clamp(168.0, 240.0);
    return AdListingGridMetrics(
      gap: gap,
      cellWidth: width,
      mediaHeight: mediaHeight,
      bodyHeight: bodyHeight,
      tileHeight: mediaHeight + bodyHeight,
    );
  }
}

/// Сетка 2×N с фиксированной высотой плитки (главная, категории, похожие).
class AdListingGrid extends StatelessWidget {
  const AdListingGrid({
    super.key,
    required this.ads,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.shrinkWrap = false,
    this.favoritesListMode = false,
    this.onRemovedFromFavorites,
  });

  final List<Map<String, dynamic>> ads;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool favoritesListMode;
  final VoidCallback? onRemovedFromFavorites;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = AdListingGridMetrics.forWidth(constraints.maxWidth);
        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
          gridDelegate: _gridDelegate(m),
          itemCount: ads.length,
          itemBuilder: (context, i) => _tile(
            ad: ads[i],
            metrics: m,
            favoritesListMode: favoritesListMode,
            onRemovedFromFavorites: onRemovedFromFavorites,
          ),
        );
      },
    );
  }
}

/// Список объявлений — полная ширина, одна карточка в ряд (поиск).
class AdListingList extends StatelessWidget {
  const AdListingList({
    super.key,
    required this.ads,
    this.padding = const EdgeInsets.fromLTRB(
      AdListingCardLayout.pagePaddingH,
      AdListingCardLayout.gridTopPadding,
      AdListingCardLayout.pagePaddingH,
      0,
    ),
    this.physics,
    this.shrinkWrap = false,
    this.favoritesListMode = false,
    this.onRemovedFromFavorites,
  });

  final List<Map<String, dynamic>> ads;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool favoritesListMode;
  final VoidCallback? onRemovedFromFavorites;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = AdListingGridMetrics.forFullWidth(constraints.maxWidth);
        return ListView.separated(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
          itemCount: ads.length,
          separatorBuilder: (_, __) => SizedBox(height: m.gap),
          itemBuilder: (context, i) => _tile(
            ad: ads[i],
            metrics: m,
            favoritesListMode: favoritesListMode,
            onRemovedFromFavorites: onRemovedFromFavorites,
          ),
        );
      },
    );
  }
}

/// Сетка объявлений внутри [CustomScrollView].
class AdListingSliverGrid extends StatelessWidget {
  const AdListingSliverGrid({
    super.key,
    required this.ads,
    this.padding = const EdgeInsets.fromLTRB(
      AdListingCardLayout.pagePaddingH,
      AdListingCardLayout.gridTopPadding,
      AdListingCardLayout.pagePaddingH,
      0,
    ),
  });

  final List<Map<String, dynamic>> ads;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final m = AdListingGridMetrics.forWidth(constraints.crossAxisExtent);
          return SliverGrid(
            gridDelegate: _gridDelegate(m),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _tile(ad: ads[i], metrics: m),
              childCount: ads.length,
            ),
          );
        },
      ),
    );
  }
}

SliverGridDelegateWithFixedCrossAxisCount _gridDelegate(AdListingGridMetrics m) {
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: m.gap,
    crossAxisSpacing: m.gap,
    mainAxisExtent: m.tileHeight,
  );
}

Widget _tile({
  required Map<String, dynamic> ad,
  required AdListingGridMetrics metrics,
  bool favoritesListMode = false,
  VoidCallback? onRemovedFromFavorites,
}) {
  return SizedBox(
    height: metrics.tileHeight,
    child: DastrassAdListingCard(
      ad: ad,
      mediaHeight: metrics.mediaHeight,
      bodyHeight: metrics.bodyHeight,
      favoritesListMode: favoritesListMode,
      onRemovedFromFavorites: onRemovedFromFavorites,
    ),
  );
}
