import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/dastrass_api.dart';
import '../theme/app_theme.dart';
import '../utils/ad_format.dart';
import '../utils/board_filter_config.dart';
import '../utils/passenger_car.dart';
import '../utils/category_tree.dart';
import '../utils/locality_label.dart';
import '../utils/board_category_style.dart';
import '../utils/network_error_message.dart';
import '../widgets/ad_listing_grid.dart';
import '../widgets/filter_subscribe_fab.dart';

/// Список объявлений: без категории — список (расми 1);
/// с `?category=…` — доска как [frontend/src/pages/AdsBoard.jsx] (расми 2).
class AdsListScreen extends StatefulWidget {
  const AdsListScreen({super.key, this.query = const {}});

  final Map<String, String> query;

  @override
  State<AdsListScreen> createState() => _AdsListScreenState();
}

class _AdsListScreenState extends State<AdsListScreen> {
  static const int _kCategoryPageSize = 20;
  late Map<String, String> _filters;
  List<dynamic> _categories = [];
  List<Map<String, dynamic>> _localities = [];
  List<dynamic> _ads = [];
  Map<String, dynamic>? _authorMeta;
  Map<String, dynamic> _filterOptions = {'brands': [], 'models': [], 'colors': []};
  int _totalCount = 0;
  bool _metaLoading = true;
  bool _adsLoading = true;
  bool _adsLoadingMore = false;
  bool _showLoadMoreButton = false;
  String? _metaError;
  late final TextEditingController _priceMinCtrl;
  late final TextEditingController _priceMaxCtrl;
  final ScrollController _categoryScrollController = ScrollController();
  Timer? _loadMoreFallbackTimer;
  bool _showSubscribeFab = false;

  bool get _categoryMode => (_filters['category'] ?? '').trim().isNotEmpty;
  bool get _isAuthorMode => (_filters['phone'] ?? '').trim().isNotEmpty;
  bool get _isSearchMode =>
      !_categoryMode && !_isAuthorMode && (_filters['q'] ?? '').trim().isNotEmpty;
  bool get _hasMoreAds => _ads.isNotEmpty && _ads.length < _totalCount;

  @override
  void initState() {
    super.initState();
    _filters = pruneBoardFilters(
      Map<String, String>.from(widget.query),
      widget.query['category'],
      widget.query['subcategory'],
    );
    _priceMinCtrl = TextEditingController(text: _filters['price_min'] ?? '');
    _priceMaxCtrl = TextEditingController(text: _filters['price_max'] ?? '');
    _categoryScrollController.addListener(_onCategoryScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _loadMoreFallbackTimer?.cancel();
    _categoryScrollController.removeListener(_onCategoryScroll);
    _categoryScrollController.dispose();
    _priceMinCtrl.dispose();
    _priceMaxCtrl.dispose();
    super.dispose();
  }

  void _onCategoryScroll() {
    if ((!_categoryMode && !_isSearchMode) || !_categoryScrollController.hasClients) return;
    final pos = _categoryScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      _triggerAutoLoadMore();
    }
  }

  void _scheduleContentFitCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (!_categoryMode && !_isSearchMode) || !_categoryScrollController.hasClients) return;
      final pos = _categoryScrollController.position;
      final nearBottom = pos.pixels >= pos.maxScrollExtent - 320;
      final shortContent = pos.maxScrollExtent <= 80;
      if (_hasMoreAds && !_adsLoadingMore && (nearBottom || shortContent)) {
        _triggerAutoLoadMore();
      }
    });
  }

  void _triggerAutoLoadMore() {
    if (_adsLoadingMore || !_hasMoreAds) return;
    _loadMoreFallbackTimer?.cancel();
    _loadMoreFallbackTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_hasMoreAds && !_adsLoadingMore) {
        setState(() => _showLoadMoreButton = true);
      }
    });
    _loadAds(append: true, fromAuto: true);
  }

  Future<void> _bootstrap() async {
    if (_categoryMode) {
      setState(() {
        _metaLoading = true;
        _metaError = null;
      });
      try {
        final results = await Future.wait([
          DastrassApi.instance.categories(),
          DastrassApi.instance.localitiesFlat(),
        ]);
        if (!mounted) return;
        setState(() {
          _categories = List<dynamic>.from(results[0] as List);
          _localities = List<Map<String, dynamic>>.from(results[1] as List);
          _filters = pruneBoardFilters(
            _filters,
            _filters['category'],
            _filters['subcategory'],
            _subcategoryPathSlugs,
          );
          _metaLoading = false;
        });
        if (boardUsesFilterOptionsApi(
          _filters['category'],
          _filters['subcategory'],
          _subcategoryPathSlugs,
        )) {
          await _loadFilterOptions();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _metaError = friendlyErrorMessage(e);
          _metaLoading = false;
        });
      }
    } else {
      setState(() => _metaLoading = false);
    }
    await _loadAds();
  }

  Future<void> _loadAds({bool append = false, bool fromAuto = false}) async {
    setState(() {
      if (append) {
        _adsLoadingMore = true;
        _showLoadMoreButton = false;
      } else {
        _adsLoading = true;
        _adsLoadingMore = false;
        _showLoadMoreButton = false;
      }
    });
    try {
      final q = Map<String, String>.from(_filters);
      q.removeWhere((k, v) => v.trim().isEmpty);
      q.putIfAbsent('limit', () => (_categoryMode || _isSearchMode) ? '$_kCategoryPageSize' : '40');
      if ((_categoryMode || _isSearchMode) && append) {
        q['offset'] = '${_ads.length}';
      }
      final data = await DastrassApi.instance.ads(q);
      if (!mounted) return;
      final list = (data['results'] as List<dynamic>?) ?? [];
      final total = data['total_count'];
      final authorRaw = data['author'];
      setState(() {
        if (append) {
          final seen = _ads.map((a) => '${(a as Map)['id'] ?? ''}').toSet();
          for (final item in list) {
            final id = '${(item as Map)['id'] ?? ''}';
            if (id.isNotEmpty && !seen.contains(id)) {
              _ads.add(item);
              seen.add(id);
            }
          }
        } else {
          _ads = list;
        }
        _totalCount = total is num ? total.toInt() : list.length;
        if (!append) {
          _authorMeta = authorRaw is Map ? Map<String, dynamic>.from(authorRaw) : null;
        }
        _adsLoading = false;
        _adsLoadingMore = false;
        _showLoadMoreButton = false;
      });
      _loadMoreFallbackTimer?.cancel();
      if (fromAuto) _scheduleContentFitCheck();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!append) _ads = [];
        _adsLoading = false;
        _adsLoadingMore = false;
        _showLoadMoreButton = append;
      });
      _loadMoreFallbackTimer?.cancel();
    }
  }

  void _syncUrl() {
    final q = Map<String, String>.from(_filters)..removeWhere((k, v) => v.trim().isEmpty);
    final uri = Uri(path: '/ads', queryParameters: q.isEmpty ? null : q);
    context.replace(uri.toString());
  }

  void _patchFilters(
    void Function(Map<String, String> f) patch, {
    bool reload = true,
    bool syncUrl = true,
  }) {
    setState(() {
      patch(_filters);
      _filters = pruneBoardFilters(
        _filters,
        _filters['category'],
        _filters['subcategory'],
        _subcategoryPathSlugs,
      );
    });
    if (syncUrl) _syncUrl();
    if (_categoryMode &&
        boardUsesFilterOptionsApi(
          _filters['category'],
          _filters['subcategory'],
          _subcategoryPathSlugs,
        )) {
      _loadFilterOptions();
    }
    if (reload) _loadAds(append: false);
  }

  Future<void> _loadFilterOptions() async {
    final cat = _filters['category'] ?? '';
    if (cat.isEmpty ||
        !boardUsesFilterOptionsApi(
          cat,
          _filters['subcategory'],
          _subcategoryPathSlugs,
        )) {
      return;
    }
    try {
      final sub = _filters['subcategory'] ?? '';
      final brand = _filters['brand'] ?? '';
      final data = await DastrassApi.instance.filterOptions(
        category: cat,
        subcategory: sub.isNotEmpty ? sub : null,
        brand: brand.isNotEmpty ? brand : null,
      );
      if (!mounted) return;
      setState(() => _filterOptions = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _filterOptions = {'brands': [], 'models': [], 'colors': []});
    }
  }

  void _applyPriceFilters() {
    _patchFilters((f) {
      f['price_min'] = _priceMinCtrl.text.trim();
      f['price_max'] = _priceMaxCtrl.text.trim();
    });
  }

  Map<String, dynamic>? get _activeCategory {
    final slug = _filters['category'] ?? '';
    if (slug.isEmpty) return null;
    for (final c in _categories) {
      final m = c as Map<String, dynamic>;
      if ('${m['slug']}' == slug) return m;
    }
    return null;
  }

  List<dynamic> get _rootSubcategories =>
      (_activeCategory?['subcategories'] as List<dynamic>?) ?? const [];

  List<Map<String, dynamic>> get _subcategoryPath {
    final sub = _filters['subcategory'] ?? '';
    if (sub.isEmpty || _rootSubcategories.isEmpty) return const [];
    return categoryFindPathBySlug(_rootSubcategories, sub);
  }

  List<String> get _subcategoryPathSlugs =>
      subcategoryPathSlugsFromNodes(_subcategoryPath);

  List<dynamic> get _visibleSubcategoryNodes {
    final sub = _filters['subcategory'] ?? '';
    if (sub.isEmpty) return _rootSubcategories;
    final current = categoryFindNodeBySlug(_rootSubcategories, sub);
    final children = current?['children'] as List<dynamic>? ?? const [];
    if (children.isNotEmpty) return children;
    final path = _subcategoryPath;
    if (path.length > 1) {
      final parent = path[path.length - 2];
      return parent['children'] as List<dynamic>? ?? const [];
    }
    return _rootSubcategories;
  }

  List<Map<String, dynamic>> get _filteredVisibleSubNodes {
    final sub = _filters['subcategory'] ?? '';
    return _visibleSubcategoryNodes
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((s) {
          if (categoryNodeContainsSlug(s, sub)) return true;
          return categoryHasPositiveCountInTree(s);
        })
        .toList();
  }

  bool get _hasSubcategory => (_filters['subcategory'] ?? '').trim().isNotEmpty;

  List<BoardFilterField> get _boardFilterFields => getBoardFilterFields(
        _filters['category'],
        _filters['subcategory'],
        _subcategoryPathSlugs,
      );

  List<int> get _platformYears {
    final years = <int>{};
    for (final raw in _ads) {
      final y = int.tryParse('${(raw as Map)['year'] ?? ''}');
      if (y != null && y > 1900 && y < 2100) years.add(y);
    }
    final ymin = int.tryParse(_filters['year_min'] ?? '');
    final ymax = int.tryParse(_filters['year_max'] ?? '');
    if (ymin != null && ymin > 1900 && ymin < 2100) years.add(ymin);
    if (ymax != null && ymax > 1900 && ymax < 2100) years.add(ymax);
    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<Map<String, dynamic>> get _filterBrands {
    final raw = _filterOptions['brands'];
    if (raw is! List) return const [];
    return raw.map((e) {
      if (e is String) return {'name': e, 'count': null};
      return Map<String, dynamic>.from(e as Map);
    }).toList();
  }

  List<Map<String, dynamic>> get _modelsToShow {
    final raw = _filterOptions['models'];
    final fromApi = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is String) {
          fromApi.add({'name': e, 'count': null});
        } else {
          fromApi.add(Map<String, dynamic>.from(e as Map));
        }
      }
    }
    if (fromApi.isEmpty) {
      final brand = (_filters['brand'] ?? '').trim().toLowerCase();
      if (brand.isEmpty) return const [];
      final map = <String, int>{};
      for (final rawAd in _ads) {
        final ad = rawAd as Map<String, dynamic>;
        final adBrand = '${ad['brand'] ?? ''}'.trim().toLowerCase();
        final adModel = '${ad['model'] ?? ''}'.trim();
        if (adModel.isEmpty || adBrand != brand) continue;
        map[adModel] = (map[adModel] ?? 0) + 1;
      }
      final list = map.entries.map((e) => {'name': e.key, 'count': e.value}).toList();
      list.sort((a, b) => ((b['count'] as num?) ?? 0).compareTo((a['count'] as num?) ?? 0));
      return list;
    }
    return fromApi.where((m) {
      final c = m['count'];
      return c is! num || c > 0;
    }).toList();
  }

  String get _authorPhone => (_filters['phone'] ?? '').trim();

  String get _authorName {
    final fromApi = '${_authorMeta?['name'] ?? ''}'.trim();
    if (fromApi.isNotEmpty) return fromApi;
    for (final item in _ads) {
      if (item is! Map) continue;
      final name = '${item['seller_name'] ?? ''}'.trim();
      if (name.isNotEmpty && name != 'Автор объявления') return name;
    }
    return '';
  }

  String? get _authorAvatarUrl {
    final fromApi = normalizeMediaUrl('${_authorMeta?['avatar_url'] ?? ''}');
    if (fromApi.isNotEmpty) return fromApi;
    for (final item in _ads) {
      if (item is! Map) continue;
      final url = normalizeMediaUrl('${item['seller_avatar_url'] ?? ''}');
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  String get _authorInitials {
    final name = _authorName;
    if (name.isNotEmpty) {
      final p = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final a = p.isNotEmpty ? p.first[0] : '';
      final b = p.length > 1 ? p.last[0] : '';
      final s = '$a$b'.trim();
      if (s.isNotEmpty) return s.toUpperCase();
    }
    final digits = _authorPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2).toUpperCase();
    return '?';
  }

  String get _pageHeading {
    if (_isAuthorMode) return 'Объявления автора';
    final cat = _activeCategory;
    if (cat == null) return 'Категория';
    final brand = _filters['brand'] ?? '';
    final sub = _filters['subcategory'] ?? '';
    if (brand.isNotEmpty && sub.isNotEmpty) return brand;
    if (sub.isNotEmpty) {
      final node = categoryFindNodeBySlug(_rootSubcategories, sub);
      final name = '${node?['name'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
    return '${cat['name'] ?? ''}';
  }

  void _onCategoryBack() {
    final model = _filters['model'] ?? '';
    if (model.isNotEmpty) {
      _patchFilters((f) => f['model'] = '');
      return;
    }
    final brand = _filters['brand'] ?? '';
    if (brand.isNotEmpty) {
      _patchFilters((f) {
        f['brand'] = '';
        f['model'] = '';
      });
      return;
    }
    final sub = _filters['subcategory'] ?? '';
    if (sub.isNotEmpty) {
      final path = _subcategoryPath;
      final parentSlug = path.length > 1 ? '${path[path.length - 2]['slug']}' : '';
      _patchFilters((f) {
        f['subcategory'] = parentSlug;
        f['brand'] = '';
        f['model'] = '';
      });
      return;
    }
    if ((_filters['category'] ?? '').isNotEmpty) {
      context.go('/home');
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _onSystemBack() {
    if (_categoryMode) {
      _onCategoryBack();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _onSubcategoryPillTap(Map<String, dynamic> node) {
    final slug = '${node['slug']}';
    final exact = _filters['subcategory'] == slug;
    _patchFilters((f) {
      if (exact) {
        f['subcategory'] = '';
      } else {
        f['subcategory'] = slug;
      }
      f['brand'] = '';
      f['model'] = '';
    });
  }

  void _onBrandPillTap(String name) {
    final exact = _filters['brand'] == name;
    _patchFilters((f) {
      f['brand'] = exact ? '' : name;
      f['model'] = '';
    });
  }

  void _onModelPillTap(String name) {
    final exact = _filters['model'] == name;
    _patchFilters((f) => f['model'] = exact ? '' : name);
  }

  Widget _buildAuthorIntro(BuildContext context) {
    final onBg = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).hintColor;
    final avatar = _authorAvatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Объявления автора',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: onBg,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: muted.withValues(alpha: 0.2),
                  border: Border.all(color: muted.withValues(alpha: 0.35)),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatar != null
                    ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          _authorInitials,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: onBg),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Автор',
                      style: TextStyle(
                        fontSize: 12,
                        color: onBg.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_authorName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: onBg,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        final uri = Uri(scheme: 'tel', path: _authorPhone);
                        launchUrl(uri);
                      },
                      child: Text(
                        _authorPhone,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSearchMode) {
      return _buildSearchScaffold(context);
    }
    if (!_categoryMode) {
      return _buildSimpleListScaffold(context);
    }
    final light = Theme.of(context).brightness == Brightness.light;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onSystemBack();
      },
      child: Scaffold(
      backgroundColor: light ? AppColors.bgLight : AppColors.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            _metaLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _metaError != null
                    ? _errorBody(_metaError!)
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async {
                          await _bootstrap();
                        },
                        child: CustomScrollView(
                          controller: _categoryScrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(child: _buildCategoryPageHead(context)),
                            if (_isAuthorMode) SliverToBoxAdapter(child: _buildAuthorIntro(context)),
                            if (!_isAuthorMode) SliverToBoxAdapter(child: _buildCategoryFilters(context)),
                            if (_filteredVisibleSubNodes.isNotEmpty)
                              SliverToBoxAdapter(child: _buildSubcategoryPills()),
                            if (_hasSubcategory &&
                                boardShowsBrandFilters(
                                  _filters['category'],
                                  _filters['subcategory'],
                                  _subcategoryPathSlugs,
                                ) &&
                                _filterBrands.isNotEmpty &&
                                _filteredVisibleSubNodes.isEmpty)
                              SliverToBoxAdapter(child: _buildBrandPills()),
                            if (_hasSubcategory &&
                                boardShowsBrandFilters(
                                  _filters['category'],
                                  _filters['subcategory'],
                                  _subcategoryPathSlugs,
                                ) &&
                                !_boardFilterFields.any((f) => f.kind == BoardFilterKind.model) &&
                                (_filters['brand'] ?? '').isNotEmpty &&
                                _modelsToShow.isNotEmpty)
                              SliverToBoxAdapter(child: _buildModelPills()),
                            _buildAdsSliver(context),
                            _buildLoadMoreSliver(),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: filterSubscribeBarBottomInset(context) +
                                    (_showSubscribeFab ? kFilterSubscribeFabHeight : 0),
                              ),
                            ),
                          ],
                        ),
                      ),
            if (!_isAuthorMode)
              FilterSubscribeFab(
                filters: _filters,
                onVisibilityChanged: (visible) {
                  if (_showSubscribeFab != visible) {
                    setState(() => _showSubscribeFab = visible);
                  }
                },
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCategoryPageHead(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final onTitle = Theme.of(context).colorScheme.onSurface;
    final countColor = light ? BoardCategoryStyle.countColorLight : Colors.white.withValues(alpha: 0.52);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoardCategoryStyle.pagePadH,
        4,
        BoardCategoryStyle.pagePadH,
        BoardCategoryStyle.headBottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: BoardCategoryStyle.backBgLight(light),
            borderRadius: BorderRadius.circular(BoardCategoryStyle.backRadius),
            child: InkWell(
              onTap: _onCategoryBack,
              borderRadius: BorderRadius.circular(BoardCategoryStyle.backRadius),
              child: const SizedBox(
                width: BoardCategoryStyle.backSize,
                height: BoardCategoryStyle.backSize,
                child: Center(
                  child: Text(
                    '←',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 19.2,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: BoardCategoryStyle.headGap),
          Expanded(
            child: _metaLoading
                ? Text(
                    'Загрузка…',
                    style: TextStyle(
                      fontSize: BoardCategoryStyle.titleSize,
                      fontWeight: FontWeight.w800,
                      color: onTitle,
                    ),
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _pageHeading,
                          style: TextStyle(
                            fontSize: BoardCategoryStyle.titleSize,
                            fontWeight: FontWeight.w800,
                            color: onTitle,
                            height: 1.2,
                          ),
                        ),
                        TextSpan(
                          text: ' ($_totalCount)',
                          style: TextStyle(
                            fontSize: BoardCategoryStyle.titleSize * 0.95,
                            fontWeight: BoardCategoryStyle.countWeight,
                            color: countColor,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchScaffold(BuildContext context) {
    final q = (_filters['q'] ?? '').trim();
    final light = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: light ? AppColors.bgLight : AppColors.bgDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(q.isEmpty ? 'Поиск' : q),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAds,
        child: _adsLoading && _ads.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _ads.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 48),
                      Center(
                        child: Text(
                          q.isEmpty ? 'Ничего не найдено' : 'По запросу «$q» ничего не найдено.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ),
                    ],
                  )
                : CustomScrollView(
                    controller: _categoryScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                'Результаты поиска',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      letterSpacing: -0.3,
                                    ),
                              ),
                              if (_totalCount > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '($_totalCount)',
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      AdListingSliverGrid(
                        ads: _ads.cast<Map<String, dynamic>>(),
                      ),
                      _buildLoadMoreSliver(),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSimpleListScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(_isAuthorMode ? 'Объявления автора' : 'Объявления'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAds,
        child: _adsLoading && _ads.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _ads.isEmpty
                ? ListView(
                    children: [
                      if (_isAuthorMode) _buildAuthorIntro(context),
                      const SizedBox(height: 48),
                      Center(
                        child: Text(
                          'Ничего не найдено',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                    children: [
                      if (_isAuthorMode) _buildAuthorIntro(context),
                      AdListingList(
                        ads: _ads.cast<Map<String, dynamic>>(),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _errorBody(String msg) {
    return ListView(
      children: [
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(msg, style: TextStyle(color: Theme.of(context).hintColor)),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final menuBg = light ? Colors.white : AppColors.cardDark;
    final muted = light ? BoardCategoryStyle.mutedLight : Colors.white.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoardCategoryStyle.pagePadH,
        0,
        BoardCategoryStyle.pagePadH,
        10,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BoardCategoryStyle.filtersPadH,
          vertical: BoardCategoryStyle.filtersPadV,
        ),
        decoration: BoxDecoration(
          color: BoardCategoryStyle.filtersBg(light),
          borderRadius: BorderRadius.circular(BoardCategoryStyle.filtersRadius),
          border: Border.all(color: BoardCategoryStyle.filtersBorder(light)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownSearch<String>(
              key: ValueKey('city_${_localities.length}_${_filters['city']}'),
              selectedItem: (_filters['city'] ?? '').isNotEmpty ? _filters['city'] : null,
              enabled: _localities.isNotEmpty,
              items: (filter, _) async {
                final q = filter.trim().toLowerCase();
                final out = <String>[];
                for (final e in selectableLocalities(_localities)) {
                  final id = '${e['id']}';
                  final label = localitySelectLabel(e).toLowerCase();
                  if (q.isEmpty || label.contains(q) || id.contains(q)) out.add(id);
                }
                return out;
              },
              itemAsString: (id) {
                for (final e in _localities) {
                  if ('${e['id']}' == id) return localitySelectLabel(e);
                }
                return id;
              },
              onSelected: (v) => _patchFilters((f) => f['city'] = v ?? ''),
              popupProps: PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    hintText: 'Поиск…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                menuProps: MenuProps(
                  backgroundColor: menuBg,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              decoratorProps: DropDownDecoratorProps(
                baseStyle: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
                decoration: BoardCategoryStyle.cityDecoration(light: light),
              ),
            ),
            const SizedBox(height: BoardCategoryStyle.filtersGap),
            Row(
              children: [
                Text(
                  'Цена:',
                  style: TextStyle(
                    fontSize: BoardCategoryStyle.pillFontSize,
                    fontWeight: FontWeight.w400,
                    color: muted,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(child: _priceField(hint: 'от', controller: _priceMinCtrl)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    '—',
                    style: TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w700,
                      fontSize: BoardCategoryStyle.pillFontSize,
                    ),
                  ),
                ),
                Expanded(child: _priceField(hint: 'до', controller: _priceMaxCtrl)),
              ],
            ),
            if (_hasSubcategory && _boardFilterFields.isNotEmpty) ..._buildSpecFilterRows(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSpecFilterRows(BuildContext context) {
    final fields = _boardFilterFields;
    if (fields.isEmpty) return const [];

    final colors = (_filterOptions['colors'] as List<dynamic>?) ?? const [];
    final years = _platformYears;
    final rows = <List<BoardFilterField>>[];
    for (var i = 0; i < fields.length; i += 2) {
      rows.add(fields.sublist(i, i + 2 > fields.length ? fields.length : i + 2));
    }

    return [
      for (var ri = 0; ri < rows.length; ri++) ...[
        const SizedBox(height: BoardCategoryStyle.filtersGap),
        Row(
          children: [
            for (var ci = 0; ci < rows[ri].length; ci++) ...[
              if (ci > 0) const SizedBox(width: 8),
              Expanded(child: _specFieldWidget(rows[ri][ci], colors, years)),
            ],
            if (rows[ri].length == 1) const Expanded(child: SizedBox()),
          ],
        ),
      ],
    ];
  }

  Widget _priceField({required String hint, required TextEditingController controller}) {
    final light = Theme.of(context).brightness == Brightness.light;
    return SizedBox(
      height: BoardCategoryStyle.inputHeight,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(
          fontSize: BoardCategoryStyle.inputFontSize,
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
        decoration: BoardCategoryStyle.inputDecoration(hint: hint, light: light),
        onSubmitted: (_) => _applyPriceFilters(),
        onEditingComplete: _applyPriceFilters,
      ),
    );
  }

  Widget _buildSubcategoryPills() {
    final nodes = _filteredVisibleSubNodes;
    final sub = _filters['subcategory'] ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoardCategoryStyle.pagePadH,
        0,
        BoardCategoryStyle.pagePadH,
        12,
      ),
      child: _TwoRowCollapsibleWrap(
        children: [for (final s in nodes) _subcategoryPill(s, sub)],
      ),
    );
  }

  Widget _subcategoryPill(Map<String, dynamic> node, String activeSub) {
    return _boardPill(
      label: '${node['name'] ?? ''}',
      count: node['ads_count'],
      active: categoryNodeContainsSlug(node, activeSub),
      onTap: () => _onSubcategoryPillTap(node),
    );
  }

  Widget _buildBrandPills() {
    final active = _filters['brand'] ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoardCategoryStyle.pagePadH,
        0,
        BoardCategoryStyle.pagePadH,
        12,
      ),
      child: _TwoRowCollapsibleWrap(
        children: [
          for (final b in _filterBrands)
            _countPill(
              label: '${b['name'] ?? ''}',
              count: b['count'],
              active: active == '${b['name']}',
              onTap: () => _onBrandPillTap('${b['name']}'),
            ),
        ],
      ),
    );
  }

  Widget _buildModelPills() {
    final active = _filters['model'] ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoardCategoryStyle.pagePadH,
        0,
        BoardCategoryStyle.pagePadH,
        12,
      ),
      child: _TwoRowCollapsibleWrap(
        children: [
          for (final m in _modelsToShow)
            _countPill(
              label: '${m['name'] ?? ''}',
              count: m['count'],
              active: active == '${m['name']}',
              onTap: () => _onModelPillTap('${m['name']}'),
            ),
        ],
      ),
    );
  }

  Widget _countPill({
    required String label,
    required dynamic count,
    required bool active,
    required VoidCallback onTap,
  }) {
    return _boardPill(label: label, count: count, active: active, onTap: onTap);
  }

  Widget _boardPill({
    required String label,
    required dynamic count,
    required bool active,
    required VoidCallback onTap,
  }) {
    final light = Theme.of(context).brightness == Brightness.light;
    final chipBg = light ? Colors.white : const Color(0x0FFFFFFF);
    final chipBorder = light ? BoardCategoryStyle.pillBorderLight : BoardCategoryStyle.inputBorderDark;
    final chipCount = light ? BoardCategoryStyle.mutedLight : Colors.white.withValues(alpha: 0.7);
    final countStr = count is num ? NumberFormat.decimalPattern('ru_RU').format(count) : null;

    return Material(
      color: active ? BoardCategoryStyle.pillActiveBgLight : chipBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BoardCategoryStyle.pillPadH,
            vertical: BoardCategoryStyle.pillPadV,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? AppColors.primary : chipBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: BoardCategoryStyle.pillFontSize,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (countStr != null) ...[
                const SizedBox(width: 5),
                Text(
                  countStr,
                  style: TextStyle(
                    fontSize: BoardCategoryStyle.pillCountFontSize,
                    fontWeight: FontWeight.w700,
                    color: (active ? AppColors.primary : chipCount).withValues(alpha: active ? 1 : 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _specFieldWidget(
    BoardFilterField field,
    List<dynamic> apiColors,
    List<int> years,
  ) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    if (field.kind == BoardFilterKind.attr
        || field.kind == BoardFilterKind.volume
        || field.kind == BoardFilterKind.area
        || field.kind == BoardFilterKind.floor
        || field.kind == BoardFilterKind.memory
        || field.kind == BoardFilterKind.size) {
      return SizedBox(
        height: BoardCategoryStyle.inputHeight,
        child: TextField(
          key: ValueKey('field_${field.key}'),
          style: TextStyle(
            fontSize: BoardCategoryStyle.inputFontSize,
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w400,
          ),
          decoration: BoardCategoryStyle.inputDecoration(hint: field.label, light: light),
          onSubmitted: (v) => _patchFilters((f) => f[field.key] = v.trim()),
        ),
      );
    }

    List<MapEntry<String, String>> options;
    switch (field.kind) {
      case BoardFilterKind.transmission:
        options = transmissionLabels.entries.map((e) => MapEntry(e.key, e.value)).toList();
      case BoardFilterKind.fuel:
        options = fuelLabels.entries.map((e) => MapEntry(e.key, e.value)).toList();
      case BoardFilterKind.color:
        options = [];
        for (final c in apiColors) {
          if (c is Map) {
            final code = '${c['code'] ?? ''}'.trim();
            final label = '${c['label'] ?? ''}'.trim();
            if (code.isNotEmpty) {
              options.add(MapEntry(code, label.isNotEmpty ? label : (colorLabels[code] ?? code)));
            }
          } else {
            final s = '$c'.trim();
            if (s.isNotEmpty) options.add(MapEntry(s, colorLabels[s] ?? s));
          }
        }
      case BoardFilterKind.year:
        options = [for (final y in years) MapEntry('$y', '$y')];
      case BoardFilterKind.body:
        options = [
          for (final name in PassengerCarConfig.bodyTypes) MapEntry(name, name),
        ];
      case BoardFilterKind.model:
        final raw = _filterOptions['models'];
        options = [];
        if (raw is List) {
          for (final m in raw) {
            final name = m is String ? m : '${(m as Map)['name'] ?? ''}';
            if (name.isNotEmpty) options.add(MapEntry(name, name));
          }
        }
      case BoardFilterKind.condition:
        options = [for (final o in deviceConditionOptions) MapEntry(o, o)];
      case BoardFilterKind.area:
      case BoardFilterKind.floor:
      case BoardFilterKind.size:
      case BoardFilterKind.volume:
      case BoardFilterKind.attr:
      case BoardFilterKind.memory:
        options = [];
    }
    return _specDropdown(
      keyId: field.key,
      hint: field.label,
      value: _filters[field.key],
      options: options,
    );
  }

  Widget _specDropdown({
    required String keyId,
    required String hint,
    required String? value,
    required List<MapEntry<String, String>> options,
  }) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final menuBg = light ? Colors.white : AppColors.cardDark;
    final selected = (value ?? '').isNotEmpty ? value : null;

    return SizedBox(
      height: BoardCategoryStyle.inputHeight,
      child: DropdownSearch<String>(
      key: ValueKey('spec_${keyId}_${options.length}_$selected'),
      selectedItem: selected,
      items: (filter, _) async {
        final q = filter.trim().toLowerCase();
        return options
            .where((e) => q.isEmpty || e.value.toLowerCase().contains(q))
            .map((e) => e.key)
            .toList();
      },
      itemAsString: (k) {
        for (final e in options) {
          if (e.key == k) return e.value;
        }
        return k;
      },
      onSelected: (v) => _patchFilters((f) => f[keyId] = v ?? ''),
      popupProps: PopupProps.menu(
        showSearchBox: options.length > 8,
        menuProps: MenuProps(
          backgroundColor: menuBg,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      decoratorProps: DropDownDecoratorProps(
        baseStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: BoardCategoryStyle.inputFontSize,
          fontWeight: FontWeight.w400,
        ),
        decoration: BoardCategoryStyle.inputDecoration(hint: hint, light: light),
      ),
    ),
    );
  }

  Widget _buildAdsSliver(BuildContext context) {
    if (_adsLoading && _ads.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_ads.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'По выбранным фильтрам объявлений не найдено.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
        ),
      );
    }

    return AdListingSliverGrid(
      ads: _ads.cast<Map<String, dynamic>>(),
    );
  }

  Widget _buildLoadMoreSliver() {
    if ((!_categoryMode && !_isSearchMode) || !_hasMoreAds) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (_adsLoadingMore) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 12),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            ),
          ),
        ),
      );
    }

    if (!_showLoadMoreButton) {
      return const SliverToBoxAdapter(child: SizedBox(height: 8));
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: _triggerAutoLoadMore,
            icon: const Icon(Icons.expand_more_rounded, size: 22),
            label: const Text(
              'Загрузить ещё',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.4),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Чипы в 2 ряда; кнопка «Все» раскрывает остальные.
class _TwoRowCollapsibleWrap extends StatefulWidget {
  const _TwoRowCollapsibleWrap({required this.children});

  final List<Widget> children;

  @override
  State<_TwoRowCollapsibleWrap> createState() => _TwoRowCollapsibleWrapState();
}

class _TwoRowCollapsibleWrapState extends State<_TwoRowCollapsibleWrap> {
  static const double _rowHeight = 32;
  static const double _runSpacing = BoardCategoryStyle.pillGap;
  static const int _maxRows = 2;

  static double get _maxHeight => _rowHeight * _maxRows + _runSpacing * (_maxRows - 1);

  bool _expanded = false;
  final GlobalKey _measureKey = GlobalKey();
  bool _needsMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateNeedsMore());
  }

  @override
  void didUpdateWidget(covariant _TwoRowCollapsibleWrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      if (_expanded) {
        setState(() => _expanded = false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateNeedsMore());
    }
  }

  void _updateNeedsMore() {
    final ctx = _measureKey.currentContext;
    if (ctx == null || !mounted) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox) return;
    final needs = ro.size.height > _maxHeight + 1;
    if (needs != _needsMore) setState(() => _needsMore = needs);
  }

  Widget _wrap(List<Widget> children) {
    return Wrap(
      spacing: BoardCategoryStyle.pillGap,
      runSpacing: _runSpacing,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final light = Theme.of(context).brightness == Brightness.light;
    final moreBtn = Material(
      color: light ? Colors.white : const Color(0x0FFFFFFF),
      shape: StadiumBorder(
        side: BorderSide(
          color: light ? BoardCategoryStyle.moreBorderLight : BoardCategoryStyle.inputBorderDark,
        ),
      ),
      child: InkWell(
        onTap: _needsMore
            ? () {
                setState(() => _expanded = !_expanded);
                WidgetsBinding.instance.addPostFrameCallback((_) => _updateNeedsMore());
              }
            : null,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BoardCategoryStyle.morePadH,
            vertical: BoardCategoryStyle.morePadV,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _expanded ? 'Скрыть' : 'Все',
                style: TextStyle(
                  fontSize: BoardCategoryStyle.moreFontSize,
                  fontWeight: FontWeight.w700,
                  color: light ? BoardCategoryStyle.moreTextLight : Colors.white.withValues(alpha: 0.78),
                ),
              ),
              Icon(
                _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: light ? BoardCategoryStyle.moreTextLight : Colors.white.withValues(alpha: 0.78),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Offstage(
          child: KeyedSubtree(
            key: _measureKey,
            child: _wrap(widget.children),
          ),
        ),
        ClipRect(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _expanded ? double.infinity : _maxHeight,
            ),
            child: _wrap(widget.children),
          ),
        ),
        if (_needsMore) Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: moreBtn)),
      ],
    );
  }
}
