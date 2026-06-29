import 'package:flutter/material.dart';

import 'progressive_network_image.dart';

/// Нейтральная заглушка для объявлений без фото (не шаблон/placeholder для ревью).
class AdNoPhotoPlaceholder extends StatelessWidget {
  const AdNoPhotoPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  const AdNoPhotoPlaceholder.expand({
    super.key,
    this.borderRadius,
  })  : width = null,
        height = null;

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1C2433) : const Color(0xFFE9EDF3);
    final iconColor = dark ? const Color(0xFF7C8AA5) : const Color(0xFF8B97AB);

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: bg,
      ),
      child: Icon(Icons.photo_camera_outlined, size: 32, color: iconColor),
    );
  }
}

/// Миниатюра объявления: фото или нейтральная иконка.
class AdPhotoThumb extends StatelessWidget {
  const AdPhotoThumb({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.fit = BoxFit.cover,
    this.memCacheWidth,
  });

  final String imageUrl;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final fallback = AdNoPhotoPlaceholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );

    if (imageUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: ProgressiveNetworkImage(
          imageUrl: imageUrl,
          fit: fit,
          width: width,
          height: height,
          previewCacheWidth: memCacheWidth,
          placeholder: ImageLoadingPlaceholder(
            width: width,
            height: height,
            borderRadius: borderRadius,
          ),
          errorWidget: fallback,
        ),
      ),
    );
  }
}
