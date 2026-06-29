import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/compare_store.dart';
import '../services/dastrass_api.dart';
import '../theme/app_theme.dart';
import '../utils/ad_format.dart';
import '../utils/compare_fields.dart';
import 'ad_no_photo_placeholder.dart';

/// Вкладка «Сравнение» — мисли [frontend/src/components/ComparePanel.jsx].
class CompareTabPanel extends StatefulWidget {
  const CompareTabPanel({super.key});

  @override
  State<CompareTabPanel> createState() => _CompareTabPanelState();
}

class _CompareTabPanelState extends State<CompareTabPanel> {
  List<dynamic> _categories = [];
  String _activeCatSlug = '';
  List<Map<String, dynamic>> _items = const [];
  bool _loading = false;
  bool _loadingAds = false;
  int _idsTick = 0;

  @override
  void initState() {
    super.initState();
    CompareStore.instance.addListener(_onCompareChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    CompareStore.instance.removeListener(_onCompareChanged);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await CompareStore.instance.hydrate();
    await _loadCategories();
    if (!mounted) return;
    _pickDefaultCategory();
    await _reloadAds();
  }

  void _onCompareChanged() {
    if (!mounted) return;
    setState(() => _idsTick++);
    _pickDefaultCategory();
    _reloadAds();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await DastrassApi.instance.categories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _reloadAds() async {
    if (_loadingAds) return;
    _loadingAds = true;
    if (mounted) setState(() => _loading = true);

    final slug = _activeCatSlug;
    final ids = slug.isEmpty ? <int>[] : CompareStore.instance.idsFor(slug);
    if (ids.isEmpty) {
      if (mounted) {
        setState(() {
          _items = const [];
          _loading = false;
        });
      }
      _loadingAds = false;
      return;
    }

    try {
      final results = await Future.wait(
        ids.map((id) async {
          try {
            return await DastrassApi.instance.adDetail('$id');
          } catch (_) {
            return null;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _items = results.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } finally {
      _loadingAds = false;
    }
  }

  void _pickDefaultCategory() {
    if (_categories.isEmpty) return;
    if (_activeCatSlug.isNotEmpty &&
        CompareStore.instance.idsFor(_activeCatSlug).isNotEmpty) {
      return;
    }
    for (final c in _categories) {
      if (c is Map) {
        final slug = '${c['slug'] ?? ''}';
        if (CompareStore.instance.idsFor(slug).isNotEmpty) {
          _activeCatSlug = slug;
          return;
        }
      }
    }
    if (_activeCatSlug.isEmpty && _categories.first is Map) {
      _activeCatSlug = '${(_categories.first as Map)['slug'] ?? ''}';
    }
  }

  Future<void> _removeOne(int id) async {
    await CompareStore.instance.toggle(id, categorySlug: _activeCatSlug);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Удалено из сравнения')),
    );
  }

  void _selectCategory(String slug) {
    if (slug == _activeCatSlug) return;
    setState(() => _activeCatSlug = slug);
    _reloadAds();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final _ = _idsTick;
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    final muted = theme.hintColor;
    final total = CompareStore.instance.count;

    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Сравнение пустое',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: onBg),
            ),
            const SizedBox(height: 8),
            Text(
              'Во вкладке «Избранные» нажмите «Сравнить» (до ${CompareStore.maxItems} в каждой категории).',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          ],
        ),
      );
    }

    final profile = _activeCatSlug.isNotEmpty
        ? profileForCategorySlug(_activeCatSlug)
        : CompareProfile.catalog;
    final rows = getCompareRows(profile);
    final catIds = _activeCatSlug.isEmpty
        ? const <int>[]
        : CompareStore.instance.idsFor(_activeCatSlug);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i] as Map<String, dynamic>;
                final slug = '${cat['slug'] ?? ''}';
                final active = slug == _activeCatSlug;
                final n = CompareStore.instance.idsFor(slug).length;
                final isDark = theme.brightness == Brightness.dark;
                final chipBg = active
                    ? AppColors.primary
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF1F3F5));
                final chipFg = active
                    ? Colors.white
                    : (isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF212529));

                return Material(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _selectCategory(slug),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${cat['name'] ?? ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: chipFg,
                            ),
                          ),
                          if (n > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (catIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                compareEmptyCategoryHint,
                style: TextStyle(color: muted, fontSize: 14, height: 1.45),
              ),
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else
            _CompareBoard(
              items: _items,
              rows: rows,
              onBg: onBg,
              onRemove: _removeOne,
            ),
        ],
      ),
    );
  }
}

class _CompareBoard extends StatefulWidget {
  const _CompareBoard({
    required this.items,
    required this.rows,
    required this.onBg,
    required this.onRemove,
  });

  final List<Map<String, dynamic>> items;
  final List<CompareRow> rows;
  final Color onBg;
  final Future<void> Function(int id) onRemove;

  @override
  State<_CompareBoard> createState() => _CompareBoardState();
}

class _CompareBoardState extends State<_CompareBoard> {
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  _CompareMetrics _metrics(BuildContext context) => _CompareMetrics.of(context);

  TextStyle _cellStyle() => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: widget.onBg,
        height: 1.2,
      );

  TextStyle _labelStyle() => _cellStyle().copyWith(fontSize: 12.5);

  Color _dividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFE9ECEF)
        : const Color(0x24FFFFFF);
  }

  Widget _photoCell(BuildContext context, Map<String, dynamic> ad, _CompareMetrics m) {
    final id = int.tryParse('${ad['id']}') ?? 0;
    final img = resolveAdImageUrl(ad);
    return SizedBox(
      width: m.colWidth,
      height: m.headerH,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: m.photoSize,
          height: m.photoSize,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: id > 0 ? () => context.push('/ads/$id') : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: img.isNotEmpty
                          ? AdPhotoThumb(
                              imageUrl: img,
                              width: m.photoSize,
                              height: m.photoSize,
                              memCacheWidth: 320,
                            )
                          : _placeholder(m.photoSize),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Material(
                  color: const Color(0xFFE53935),
                  elevation: 1,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: id > 0 ? () => widget.onRemove(id) : null,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labelCell(String label, _CompareMetrics m, Color divider) {
    return Container(
      width: m.labelWidth,
      height: m.rowH,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider, width: 1)),
      ),
      child: Text(
        label,
        style: _labelStyle(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _valueCell(String value, _CompareMetrics m, Color divider) {
    return Container(
      width: m.colWidth,
      height: m.rowH,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider, width: 1)),
      ),
      child: Text(
        value,
        style: _cellStyle(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _dataColumn(
    BuildContext context,
    Map<String, dynamic> ad,
    _CompareMetrics m,
    Color divider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _photoCell(context, ad, m),
        for (final row in widget.rows) _valueCell(row.get(ad), m, divider),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _metrics(context);
    final divider = _dividerColor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: m.labelWidth, height: m.headerH),
            for (final row in widget.rows) _labelCell(row.label, m, divider),
          ],
        ),
        SizedBox(width: m.labelGap),
        Expanded(
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.items.length; i++) ...[
                  if (i > 0) SizedBox(width: m.colGap),
                  _dataColumn(context, widget.items[i], m, divider),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(double size) {
    return AdNoPhotoPlaceholder(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(10),
    );
  }
}

class _CompareMetrics {
  const _CompareMetrics({
    required this.labelWidth,
    required this.photoSize,
    required this.colWidth,
    required this.rowH,
    required this.headerH,
    required this.colGap,
    required this.labelGap,
  });

  final double labelWidth;
  final double photoSize;
  final double colWidth;
  final double rowH;
  final double headerH;
  final double colGap;
  final double labelGap;

  factory _CompareMetrics.of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final photo = w >= 768 ? 112.0 : 96.0;
    return _CompareMetrics(
      labelWidth: 104,
      photoSize: photo,
      colWidth: photo + 10.4,
      rowH: 40,
      headerH: photo + 5.6,
      colGap: 8,
      labelGap: 5.6,
    );
  }
}
