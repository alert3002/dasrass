import 'package:flutter/material.dart';

import 'dastrass_logo.dart';
import 'progressive_network_image.dart';

/// Placeholder for ad thumbnails without photo — мисли `.home-ad-card__media`.
class AdNoPhotoPlaceholder extends StatelessWidget {
  const AdNoPhotoPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.logoHeightFraction = 0.38,
  });

  const AdNoPhotoPlaceholder.expand({
    super.key,
    this.borderRadius,
    this.logoHeightFraction = 0.28,
  })  : width = null,
        height = null;

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double logoHeightFraction;

  static const _gradient = LinearGradient(
    begin: Alignment(-0.5, -1),
    end: Alignment(0.5, 1),
    colors: [Color(0xFF3D7CFF), Color(0xFF005BFE)],
  );

  @override
  Widget build(BuildContext context) {
    final box = LayoutBuilder(
      builder: (context, constraints) {
        final h = height ?? constraints.maxHeight;
        final logoH = (h.isFinite ? h : 96) * logoHeightFraction;
        final clampedLogoH = logoH.clamp(16.0, 72.0);

        return Center(
          child: Image.asset(
            DastrassLogo.assetPath,
            height: clampedLogoH,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Text(
              'DASRASS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: clampedLogoH * 0.32,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      },
    );

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: _gradient,
      ),
      child: box,
    );
  }
}

/// Миниатюра объявления: фото ё placeholder бренди.
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
    final placeholder = AdNoPhotoPlaceholder(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );

    if (imageUrl.isEmpty) return placeholder;

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
          errorWidget: placeholder,
        ),
      ),
    );
  }
}
