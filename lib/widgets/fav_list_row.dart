import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/compare_store.dart';
import '../services/favorites_service.dart';
import '../utils/ad_format.dart';
import '../utils/locality_label.dart';
import '../utils/time_ago.dart';
import '../theme/app_theme.dart';
import 'ad_no_photo_placeholder.dart';

/// Строка избранного — мисли [Favorites.jsx] `.fav-list-row`.
class FavListRow extends StatefulWidget {
  const FavListRow({
    super.key,
    required this.ad,
    required this.onRemoved,
  });

  final Map<String, dynamic> ad;
  final VoidCallback onRemoved;

  @override
  State<FavListRow> createState() => _FavListRowState();
}

class _FavListRowState extends State<FavListRow> {
  bool _removing = false;

  Future<void> _toggleCompare() async {
    final id = int.tryParse('${widget.ad['id'] ?? ''}') ?? 0;
    if (id <= 0) return;
    final catSlug = '${widget.ad['category_slug'] ?? ''}';
    await CompareStore.instance.hydrate();
    final wasIn = CompareStore.instance.idsFor(catSlug).contains(id);
    if (!wasIn && CompareStore.instance.idsFor(catSlug).length >= CompareStore.maxItems) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('В этой категории уже 4 объявления для сравнения')),
      );
      return;
    }
    final added = await CompareStore.instance.toggle(id, categorySlug: catSlug);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(added ? 'Добавлено в сравнение' : 'Удалено из сравнения')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = dark ? AppColors.cardDark : Colors.white;
    final borderCol = dark ? const Color(0x24FFFFFF) : const Color(0x33111827);
    final titleCol = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).hintColor;

    final id = '${widget.ad['id'] ?? ''}';
    final title = '${widget.ad['title'] ?? 'Без названия'}';
    final price = formatAdListingPrice(widget.ad['price'], '${widget.ad['currency'] ?? ''}');
    final loc = shortLocalityLabel('${widget.ad['location'] ?? ''}');
    final img = resolveAdImageUrl(widget.ad);
    final time = formatTimeAgo('${widget.ad['created_at'] ?? ''}');

    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderCol),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GestureDetector(
                      onTap: () {
                        if (id.isNotEmpty) context.push('/ads/$id');
                      },
                      child: AdPhotoThumb(
                        imageUrl: img,
                        width: 96,
                        height: 96,
                        borderRadius: BorderRadius.circular(10),
                        memCacheWidth: 256,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Material(
                      color: const Color(0xFFE53935),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _removing
                            ? null
                            : () async {
                                setState(() => _removing = true);
                                try {
                                  final res = await FavoritesService.toggle(id);
                                  if (res['ok'] == true && mounted) {
                                    widget.onRemoved();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Удалено из избранного')),
                                    );
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Не удалось удалить')),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _removing = false);
                                }
                              },
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (id.isNotEmpty) context.push('/ads/$id');
                    },
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.25,
                        color: titleCol,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: TextStyle(
                      color: titleCol,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (loc.isNotEmpty)
                    Text(loc, style: TextStyle(color: muted, fontSize: 13)),
                  if (time.isNotEmpty)
                    Text(time, style: TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ListenableBuilder(
                      listenable: CompareStore.instance,
                      builder: (context, _) {
                        final cid = int.tryParse(id) ?? 0;
                        final catSlug = '${widget.ad['category_slug'] ?? ''}';
                        final inC = CompareStore.instance.idsFor(catSlug).contains(cid);
                        return OutlinedButton(
                          onPressed: _toggleCompare,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: inC ? Colors.white : AppColors.primary,
                            backgroundColor: inC ? AppColors.primary : Colors.transparent,
                            side: BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                          child: Text(
                            inC ? 'Добавлено' : 'Сравнить',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        );
                      },
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
