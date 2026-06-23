import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/ad_format.dart';
import 'ad_no_photo_placeholder.dart';

/// Фоновая загрузка URL в disk-cache (без BuildContext).
class AdImagePrefetch {
  AdImagePrefetch._();

  static final _seen = <String>{};

  static void prefetchFromAds(Iterable<dynamic> ads) {
    final urls = <String>[];
    for (final item in ads) {
      if (item is! Map) continue;
      final url = resolveAdImageUrl(Map<String, dynamic>.from(item));
      if (url.isNotEmpty && _seen.add(url)) urls.add(url);
    }
    if (urls.isEmpty) return;
    unawaited(_downloadAll(urls));
  }

  static void prefetchUrls(Iterable<String> urls) {
    final batch = <String>[];
    for (final url in urls) {
      final u = url.trim();
      if (u.isNotEmpty && _seen.add(u)) batch.add(u);
    }
    if (batch.isEmpty) return;
    unawaited(_downloadAll(batch));
  }

  static Future<void> _downloadAll(List<String> urls) async {
    final cache = DefaultCacheManager();
    for (final url in urls) {
      try {
        await cache.downloadFile(url);
      } catch (_) {}
    }
  }
}

int _cacheWidthFor(BuildContext context, double? logicalWidth, {int fallback = 320}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  if (logicalWidth != null && logicalWidth.isFinite && logicalWidth > 0) {
    return (logicalWidth * dpr).round().clamp(96, 1600);
  }
  return (fallback * dpr).round().clamp(96, 1600);
}

/// Нейтральный фон пока грузится фото — без спиннера.
class ImageLoadingPlaceholder extends StatelessWidget {
  const ImageLoadingPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.light = false,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = light
        ? const Color(0xFFE9ECEF)
        : dark
            ? const Color(0xFF1A2235)
            : const Color(0xFFF1F3F5);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: base,
      ),
    );
  }
}

/// Сначала превью (из кэша/быстрый decode), затем полное качество с fade.
class ProgressiveNetworkImage extends StatelessWidget {
  const ProgressiveNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.previewCacheWidth,
    this.fullCacheWidth,
    this.progressive = false,
    this.fadeInDuration = const Duration(milliseconds: 280),
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? previewCacheWidth;
  final int? fullCacheWidth;
  final bool progressive;
  final Duration fadeInDuration;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    final previewW = previewCacheWidth ?? _cacheWidthFor(context, width);
    final loading = placeholder ?? ImageLoadingPlaceholder(width: width, height: height);
    final onError = errorWidget ?? loading;

    Widget image({
      required int? memCacheWidth,
      required Duration fadeIn,
      required Widget Function(BuildContext, String) placeholderBuilder,
      required Widget Function(BuildContext, String, Object) errorBuilder,
    }) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        memCacheWidth: memCacheWidth,
        fadeInDuration: fadeIn,
        fadeOutDuration: Duration.zero,
        placeholder: placeholderBuilder,
        errorWidget: errorBuilder,
      );
    }

    final useProgressive = progressive && (fullCacheWidth == null || fullCacheWidth != previewW);

    final content = useProgressive
        ? Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.center,
            children: [
              image(
                memCacheWidth: previewW,
                fadeIn: Duration.zero,
                placeholderBuilder: (_, __) => loading,
                errorBuilder: (_, __, ___) => onError,
              ),
              image(
                memCacheWidth: fullCacheWidth,
                fadeIn: fadeInDuration,
                placeholderBuilder: (_, __) => const SizedBox.shrink(),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ],
          )
        : image(
            memCacheWidth: previewW,
            fadeIn: fadeInDuration,
            placeholderBuilder: (_, __) => loading,
            errorBuilder: (_, __, ___) => onError,
          );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }
}

/// Фото в карточке объявления (главная, категории, похожие).
class AdListingImage extends StatelessWidget {
  const AdListingImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const AdNoPhotoPlaceholder.expand();
    }

    return ProgressiveNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      borderRadius: borderRadius,
      placeholder: const ImageLoadingPlaceholder(),
      errorWidget: const AdNoPhotoPlaceholder.expand(),
    );
  }
}

/// Галерея объявления: превью сразу, полное качество поверх.
class AdGalleryImage extends StatelessWidget {
  const AdGalleryImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.backgroundColor,
    this.errorChild,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Widget? errorChild;

  @override
  Widget build(BuildContext context) {
    final previewW = _cacheWidthFor(context, width, fallback: 400);

    return ColoredBox(
      color: backgroundColor ?? Colors.transparent,
      child: ProgressiveNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width,
        height: height,
        previewCacheWidth: previewW,
        fullCacheWidth: null,
        progressive: true,
        placeholder: ImageLoadingPlaceholder(
          width: width,
          height: height,
          light: backgroundColor != null,
        ),
        errorWidget: errorChild,
      ),
    );
  }
}
