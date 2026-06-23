import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import '../utils/network_error_message.dart';
import '../widgets/compare_tab_panel.dart';
import '../widgets/fav_list_row.dart';
import '../widgets/dastrass_mobile_tab_bar.dart';

/// Избранное + сравнение во вкладках (мисли [Favorites.jsx]).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.initialTab = 0});

  /// 0 — Избранные, 1 — Сравнение
  final int initialTab;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<dynamic>? _items;
  Object? _error;
  bool _loading = true;
  bool _compareTabMounted = false;

  @override
  void initState() {
    super.initState();
    _compareTabMounted = widget.initialTab == 1;
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabs.addListener(_onTabChanged);
    _load();
  }

  void _onTabChanged() {
    if (_tabs.index == 1 && !_compareTabMounted) {
      setState(() => _compareTabMounted = true);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await FavoritesService.loadList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _removeById(String id) {
    final items = _items;
    if (items == null) return;
    setState(() {
      _items = items.where((e) => '${(e as Map)['id']}' != id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      bottom: false,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabs,
          labelColor: primary,
          unselectedLabelColor: onSurface.withValues(alpha: 0.55),
          indicatorColor: primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          tabs: const [
            Tab(text: 'Избранные'),
            Tab(text: 'Сравнение'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildFavoritesTab(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, kTabScrollBottomPadding),
                child: _compareTabMounted
                    ? const CompareTabPanel()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildFavoritesTab(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final borderCol = Theme.of(context).brightness == Brightness.dark
        ? const Color(0x24FFFFFF)
        : const Color(0x33111827);
    final emptyCardBg = Theme.of(context).brightness == Brightness.dark ? AppColors.cardDark : Colors.white;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                friendlyErrorMessage(
                  _error!,
                  fallback: 'Не удалось загрузить избранное. Попробуйте ещё раз.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: onSurface.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }

    final list = _items ?? [];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, kTabScrollBottomPadding),
        children: [
          if (list.isEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                color: emptyCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: Text(
                    'У вас ещё нет избранных объявлений.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 15, height: 1.4),
                  ),
                ),
              ),
            )
          else
            ...list.map((raw) {
              final ad = raw as Map<String, dynamic>;
              final id = '${ad['id'] ?? ''}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FavListRow(
                  ad: ad,
                  onRemoved: id.isEmpty ? () {} : () => _removeById(id),
                ),
              );
            }),
        ],
      ),
    );
  }
}
