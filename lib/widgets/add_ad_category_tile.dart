import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/ad_format.dart';
import '../utils/category_icons.dart';

/// Плитка категории на шаге «Добавить» — мисли `.add-ad-category-tile`.
class AddAdCategoryTile extends StatelessWidget {
  const AddAdCategoryTile({
    super.key,
    required this.category,
    required this.onTap,
    this.imageHeight = 86,
  });

  final Map<String, dynamic> category;
  final VoidCallback onTap;
  final double imageHeight;

  Color _imageBoxBg(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return light
        ? const Color(0xFFEBEBEB).withValues(alpha: 0.68)
        : Colors.white.withValues(alpha: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final slug = '${category['slug'] ?? ''}';
    final name = '${category['name'] ?? ''}';
    final iconUrl = normalizeMediaUrl('${category['icon_url'] ?? ''}');
    final nameColor = light ? const Color(0xFF1A1F36) : Colors.white.withValues(alpha: 0.92);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: slug.isEmpty ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: ColoredBox(
                  color: _imageBoxBg(context),
                  child: iconUrl.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                          child: CachedNetworkImage(
                            imageUrl: iconUrl,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            fadeInDuration: const Duration(milliseconds: 180),
                            errorWidget: (_, __, ___) => _IconFallback(slug: slug),
                          ),
                        )
                      : _IconFallback(slug: slug),
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
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.15,
                color: nameColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddAdCategoryTileSkeleton extends StatelessWidget {
  const AddAdCategoryTileSkeleton({super.key, this.imageHeight = 86});

  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E5EB).withValues(alpha: 0.75);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: imageHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 8,
          width: 52,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        categoryIconForSlug(slug),
        size: 34,
        color: AppColors.primary.withValues(alpha: 0.72),
      ),
    );
  }
}
