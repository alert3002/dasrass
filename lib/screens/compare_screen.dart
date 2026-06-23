import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/compare_store.dart';
import '../services/dastrass_api.dart';
import '../theme/app_theme.dart';
import '../utils/locality_label.dart';
import '../widgets/ad_listing_grid.dart';
import '../widgets/dastrass_ad_listing_card.dart';
import '../widgets/dastrass_mobile_tab_bar.dart';

const _fuelLabels = {
  'diesel': 'Дизель',
  'gas': 'Газ',
  'petrol': 'Бензин',
  'electric': 'Электро',
};
const _transLabels = {
  'manual': 'Механика',
  'automatic': 'Автомат',
};
const _colorLabels = {
  'white': 'Белый',
  'black': 'Чёрный',
  'silver': 'Серебристый',
  'grey': 'Серый',
  'red': 'Красный',
  'blue': 'Синий',
  'green': 'Зелёный',
  'yellow': 'Жёлтый',
  'orange': 'Оранжевый',
  'brown': 'Коричневый',
  'beige': 'Бежевый',
  'other': 'Другой',
};

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  int _idsTick = 0;

  @override
  void initState() {
    super.initState();
    CompareStore.instance.addListener(_onCompareChanged);
    _future = _load();
  }

  @override
  void dispose() {
    CompareStore.instance.removeListener(_onCompareChanged);
    super.dispose();
  }

  void _onCompareChanged() {
    setState(() {
      _idsTick++;
      _future = _load();
    });
  }

  Future<List<Map<String, dynamic>>> _load() async {
    // ignore: unused_local_variable
    final _ = _idsTick;
    await CompareStore.instance.hydrate();
    final ids = CompareStore.instance.ids;
    final out = <Map<String, dynamic>>[];
    for (final id in ids) {
      try {
        final m = await DastrassApi.instance.adDetail('$id');
        out.add(m);
      } catch (_) {}
    }
    return out;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _clearAll() async {
    await CompareStore.instance.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сравнение очищено')),
    );
  }

  Future<void> _removeOne(int id) async {
    await CompareStore.instance.hydrate();
    final slug = CompareStore.instance.categorySlugForId(id) ?? '';
    await CompareStore.instance.toggle(id, categorySlug: slug);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Удалено из сравнения')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    final muted = theme.hintColor;
    final cardBg = theme.brightness == Brightness.dark ? AppColors.cardDark : Colors.white;
    final border = theme.brightness == Brightness.dark
        ? const Color(0x24FFFFFF)
        : const Color(0x33111827);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Сравнение'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final items = snap.data ?? [];
          return ListenableBuilder(
            listenable: CompareStore.instance,
            builder: (context, _) {
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, kTabScrollBottomPadding),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Сравнение',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => context.push('/ads'),
                          child: const Text('Добавить'),
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _clearAll,
                            child: const Text('Очистить'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      _emptyState(context, onBg, muted, cardBg, border)
                    else ...[
                      _cardsRow(context, items),
                      const SizedBox(height: 16),
                      _compareTable(context, items, onBg, muted, cardBg, border),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(
    BuildContext context,
    Color onBg,
    Color muted,
    Color cardBg,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            'Сравнение пустое',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: onBg),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте до 4 объявлений и сравните параметры.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/ads'),
            child: const Text('Перейти к объявлениям'),
          ),
        ],
      ),
    );
  }

  Widget _cardsRow(BuildContext context, List<Map<String, dynamic>> items) {
    return LayoutBuilder(
      builder: (context, c) {
        final m = AdListingGridMetrics.forWidth(c.maxWidth);
        return Wrap(
          spacing: m.gap,
          runSpacing: m.gap,
          children: items.map((ad) {
            return SizedBox(
              width: m.cellWidth,
              child: Stack(
                children: [
                  DastrassAdListingCard(
                    ad: ad,
                    mediaHeight: m.mediaHeight,
                    bodyHeight: m.bodyHeight,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          final id = int.tryParse('${ad['id']}') ?? 0;
                          if (id > 0) _removeOne(id);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.compare_arrows_rounded, size: 18, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _compareTable(
    BuildContext context,
    List<Map<String, dynamic>> items,
    Color onBg,
    Color muted,
    Color cardBg,
    Color border,
  ) {
    final rows = <_CompareRow>[
      _CompareRow('Цена', (ad) => formatAdListingPrice(ad['price'], '${ad['currency'] ?? ''}')),
      _CompareRow('Год', (ad) => '${ad['year'] ?? '—'}'),
      _CompareRow(
        'Пробег',
        (ad) {
          final m = num.tryParse('${ad['mileage'] ?? ''}');
          if (m != null && m.isFinite && m > 0) {
            return '${NumberFormat.decimalPattern('ru_RU').format(m)} км';
          }
          return '—';
        },
      ),
      _CompareRow('Топливо', (ad) {
        final f = '${ad['fuel_type'] ?? ''}';
        return _fuelLabels[f] ?? (f.isEmpty ? '—' : f);
      }),
      _CompareRow('КПП', (ad) {
        final t = '${ad['transmission'] ?? ''}';
        return _transLabels[t] ?? (t.isEmpty ? '—' : t);
      }),
      _CompareRow('Цвет', (ad) {
        final c = '${ad['color'] ?? ''}';
        return _colorLabels[c] ?? (c.isEmpty ? '—' : c);
      }),
      _CompareRow('Марка', (ad) => '${ad['brand'] ?? '—'}'),
      _CompareRow('Модель', (ad) => '${ad['model'] ?? '—'}'),
      _CompareRow('Город', (ad) {
        final label = shortLocalityLabel('${ad['location'] ?? ''}');
        return label.isEmpty ? '—' : label;
      }),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A2230)
                : const Color(0xFFF1F3F5),
            child: Text('Параметры', style: TextStyle(fontWeight: FontWeight.w800, color: onBg)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 52,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 56,
              columnSpacing: 16,
              horizontalMargin: 14,
              columns: [
                DataColumn(label: Text('', style: TextStyle(color: muted, fontWeight: FontWeight.w800))),
                ...items.map((ad) {
                  final id = int.tryParse('${ad['id']}') ?? 0;
                  return DataColumn(
                    label: SizedBox(
                      width: 120,
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => context.push('/ads/$id'),
                              child: Text(
                                '#$id',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: id > 0 ? () => _removeOne(id) : null,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Удалить', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              rows: rows.map((row) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        row.label,
                        style: TextStyle(fontWeight: FontWeight.w800, color: muted, fontSize: 13),
                      ),
                    ),
                    ...items.map((ad) => DataCell(Text('${row.get(ad)}', style: TextStyle(color: onBg)))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareRow {
  const _CompareRow(this.label, this.get);
  final String label;
  final String Function(Map<String, dynamic> ad) get;
}
