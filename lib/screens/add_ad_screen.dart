import 'dart:async';
import 'dart:typed_data';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../theme/app_theme.dart';
import '../utils/add_ad_category_order.dart';
import '../utils/ad_field_config.dart';
import '../utils/ad_form_payload.dart';
import '../utils/color_catalog.dart';
import '../utils/local_video_preview.dart';
import '../utils/locality_label.dart';
import '../utils/content_filter.dart';
import '../utils/network_error_message.dart';
import '../utils/passenger_car.dart';
import '../widgets/add_ad_category_tile.dart';
import '../widgets/dastrass_mobile_tab_bar.dart';

// --- Дарахти зердастаҳо, мисли [frontend/src/utils/categoryTree.js] ---

Map<String, dynamic>? _catFindNodeBySlug(List<dynamic>? nodes, String slug) {
  if (slug.isEmpty || nodes == null) return null;
  for (final raw in nodes) {
    final n = raw as Map<String, dynamic>;
    if ('${n['slug']}' == slug) return n;
    final hit = _catFindNodeBySlug(n['children'] as List<dynamic>?, slug);
    if (hit != null) return hit;
  }
  return null;
}

List<dynamic> _catGetChildrenForPath(List<dynamic>? rootNodes, List<String> slugPath) {
  var nodes = rootNodes ?? const <dynamic>[];
  for (final slug in slugPath) {
    if (slug.isEmpty) return const [];
    Map<String, dynamic>? found;
    for (final raw in nodes) {
      final m = raw as Map<String, dynamic>;
      if ('${m['slug']}' == slug) {
        found = m;
        break;
      }
    }
    if (found == null) return const [];
    nodes = found['children'] as List<dynamic>? ?? const [];
  }
  return nodes;
}

bool _catIsLeafSlug(List<dynamic>? rootNodes, String slug) {
  final node = _catFindNodeBySlug(rootNodes, slug);
  if (node == null) return false;
  final kids = node['children'] as List<dynamic>? ?? const [];
  return kids.isEmpty;
}

List<String> _catPathSegmentLabels(List<dynamic>? rootNodes, List<String> slugPath) {
  final names = <String>[];
  var level = rootNodes ?? const <dynamic>[];
  for (final slug in slugPath) {
    if (slug.isEmpty) break;
    Map<String, dynamic>? node;
    for (final raw in level) {
      final m = raw as Map<String, dynamic>;
      if ('${m['slug']}' == slug) {
        node = m;
        break;
      }
    }
    if (node == null) break;
    names.add('${node['name'] ?? ''}'.trim());
    level = node['children'] as List<dynamic>? ?? const [];
  }
  return names;
}

List<Map<String, String>> _catFlattenLeaves(List<dynamic>? roots, [List<String> nameTrail = const []]) {
  final out = <Map<String, String>>[];
  if (roots == null) return out;
  for (final raw in roots) {
    final n = raw as Map<String, dynamic>;
    final name = '${n['name'] ?? ''}';
    final slug = '${n['slug'] ?? ''}';
    final kids = n['children'] as List<dynamic>? ?? const [];
    final trail = [...nameTrail, name];
    if (kids.isEmpty) {
      if (slug.isNotEmpty) out.add({'slug': slug, 'full_path': trail.join(' → ')});
    } else {
      out.addAll(_catFlattenLeaves(kids, trail));
    }
  }
  return out;
}

/// «Добавить объявление» — мисли [frontend/src/pages/AddAd.jsx]: категория → форма, API `/ads/create/`.
class AddAdScreen extends StatefulWidget {
  const AddAdScreen({super.key});

  @override
  State<AddAdScreen> createState() => _AddAdScreenState();
}

class _AddAdScreenState extends State<AddAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  List<dynamic> _categories = [];
  List<dynamic> _tariffs = [];
  List<Map<String, dynamic>> _localities = [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  String? _categorySlug;
  /// Слугҳои каскадии зердаста (мисли `subcategoryPath` дар AddAd.jsx).
  List<String> _subPath = [];
  String _priceType = 'fixed';
  String? _localityId;
  /// Пустая строка = без платного тарифа.
  String _tariffId = '';
  List<String> _colorOptions = [];
  final Map<String, String> _dynamicValues = {};
  String _bodyType = '';

  final List<({String filename, Uint8List bytes})> _photos = [];
  ({String filename, Uint8List bytes})? _video;

  static final ImagePicker _imagePicker = ImagePicker();
  LocalVideoPreviewHandle? _videoPreview;
  /// 0..1 ҳангоми ирсоли `createAd` (Dio `onSendProgress`).
  double? _uploadFraction;

  int get _photoSlotsLeft => 10 - _photos.length;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = DastrassApi.instance;
      final cats = await api.categories();
      final ts = await api.tariffs();
      List<Map<String, dynamic>> loc = [];
      try {
        loc = await api.localitiesFlat();
      } catch (_) {}
      try {
        await ColorCatalog.instance.ensureLoaded();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _tariffs = ts;
        _localities = loc;
        _colorOptions = ColorCatalog.instance.optionLabels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _mainCats => orderCategoriesForAddAd(_categories);

  Map<String, dynamic>? get _currentCat {
    if (_categorySlug == null) return null;
    for (final c in _categories) {
      final m = c as Map<String, dynamic>;
      if ('${m['slug']}' == _categorySlug) return m;
    }
    return null;
  }

  List<dynamic>? get _subRoots => _currentCat?['subcategories'] as List<dynamic>?;

  /// Слуги барг барои API — вақте ки охирин `_subPath` барг аст.
  String? get _leafSubcategorySlug {
    final roots = _subRoots;
    if (_subPath.isEmpty || roots == null) return null;
    final last = _subPath.last;
    return _catIsLeafSlug(roots, last) ? last : null;
  }

  @override
  void dispose() {
    unawaited(LocalVideoPreviewHandle.close(_videoPreview));
    _videoPreview = null;
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _scrollToUploadProgress() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = PrimaryScrollController.maybeOf(context);
      if (ctrl == null || !ctrl.hasClients) return;
      ctrl.animateTo(
        ctrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildUploadProgress(Color onBg, Color muted) {
    if (!_saving || _uploadFraction == null) return const SizedBox.shrink();
    final pct = (_uploadFraction! * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Загрузка: $pct%',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onBg),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: _uploadFraction!.clamp(0.0, 1.0),
            backgroundColor: muted.withValues(alpha: 0.25),
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  void _clearDynamicValues() {
    _dynamicValues.clear();
    _bodyType = '';
  }

  List<AdDynamicField> _currentDynamicFields() {
    final cat = _categorySlug ?? '';
    final sub = _leafSubcategorySlug ?? '';
    if (cat.isEmpty || sub.isEmpty) return const [];
    final roots = _subRoots;
    final pathLabels = roots != null ? _catPathSegmentLabels(roots, _subPath) : const <String>[];
    final colors = _colorOptions.isNotEmpty ? _colorOptions : defaultColorOptionLabels();
    return getDynamicFields(
      cat,
      sub,
      subcategoryPath: _subPath,
      subcategoryFullPath: pathLabels.join(' → '),
      colorOptions: colors,
    );
  }

  bool _showBodyTypeSelect() {
    final roots = _subRoots ?? const <dynamic>[];
    final l2 = _subPath.isNotEmpty ? _catGetChildrenForPath(roots, [_subPath[0]]) : const <dynamic>[];
    final l3 = _subPath.length >= 2 ? _catGetChildrenForPath(roots, _subPath.take(2).toList()) : const <dynamic>[];
    return showPassengerBodyTypeSelect(
      isPassengerCar: isPassengerCarContext(_categorySlug, _leafSubcategorySlug, _subPath),
      subcategoryPath: _subPath,
      level2Count: l2.length,
      level3Count: l3.length,
      leafSubcategory: _leafSubcategorySlug,
    );
  }

  void _handleSubcategoryLevelPick(int levelIdx, String? slug) {
    setState(() {
      final next = <String>[];
      for (var i = 0; i < levelIdx; i++) {
        if (i < _subPath.length) next.add(_subPath[i]);
      }
      if (slug != null && slug.isNotEmpty) {
        if (next.length == levelIdx) {
          next.add(slug);
        } else {
          next[levelIdx] = slug;
          if (next.length > levelIdx + 1) {
            next.removeRange(levelIdx + 1, next.length);
          }
        }
      }
      _subPath = next;
      _clearDynamicValues();
    });
  }

  String _titlePlaceholder() {
    final roots = _subRoots;
    if (roots == null || roots.isEmpty) {
      return 'Например: марка, модель, год, краткое состояние';
    }
    var parts = _catPathSegmentLabels(roots, _subPath);
    final leaf = _leafSubcategorySlug;
    if (parts.isEmpty && leaf != null) {
      for (final m in _catFlattenLeaves(roots)) {
        if (m['slug'] == leaf) {
          final fp = m['full_path'] ?? '';
          parts = fp.split(RegExp(r'\s*→\s*')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          break;
        }
      }
    }
    final trail = parts.where((e) => e.isNotEmpty).join(' · ');
    if (trail.isEmpty) {
      return 'Например: марка, модель, год, краткое состояние';
    }
    final t = trail.length > 48 ? '${trail.substring(0, 45).trim()}…' : trail;
    return 'Например для «$t»: укажите модель, год, ключевые детали';
  }

  Future<void> _pickPhotosGallery() async {
    final slots = _photoSlotsLeft;
    if (slots <= 0) return;
    try {
      final list = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (!mounted || list.isEmpty) return;
      for (final x in list.take(slots)) {
        final b = await x.readAsBytes();
        if (b.isEmpty) continue;
        final name = x.name.isNotEmpty ? x.name : 'photo.jpg';
        _photos.add((filename: name, bytes: b));
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Галерея: ${friendlyErrorMessage(e)}')));
      }
    }
  }

  Future<void> _pickPhotoCamera() async {
    if (_photoSlotsLeft <= 0) return;
    try {
      final x = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (!mounted || x == null) return;
      final b = await x.readAsBytes();
      if (b.isEmpty) return;
      final name = x.name.isNotEmpty ? x.name : 'photo.jpg';
      setState(() => _photos.add((filename: name, bytes: b)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Камера: ${friendlyErrorMessage(e)}')));
      }
    }
  }

  Future<void> _refreshVideoPreview() async {
    await LocalVideoPreviewHandle.close(_videoPreview);
    _videoPreview = null;
    if (_video == null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      _videoPreview = await LocalVideoPreviewHandle.open(_video!.bytes, _video!.filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Превью видео: $e')),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickVideoGallery() async {
    try {
      final x = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (!mounted || x == null) return;
      final b = await x.readAsBytes();
      if (b.isEmpty) return;
      if (!mounted) return;
      const maxB = 200 * 1024 * 1024;
      if (b.length > maxB) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Видео не больше 200 МБ.')),
        );
        return;
      }
      final name = x.name.isNotEmpty ? x.name : 'video.mp4';
      setState(() {
        _video = (filename: name, bytes: b);
      });
      await _refreshVideoPreview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Видео: ${friendlyErrorMessage(e)}')));
      }
    }
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));

  void _movePhoto(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _photos.length) return;
    setState(() {
      final t = _photos[i];
      _photos[i] = _photos[j];
      _photos[j] = t;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы 1 фотографию.')),
      );
      return;
    }
    if (_categorySlug == null || _leafSubcategorySlug == null || _localityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _leafSubcategorySlug == null
                ? 'Выберите категорию полностью.'
                : 'Заполните обязательные поля',
          ),
        ),
      );
      return;
    }

    final dynamicFields = _currentDynamicFields();
    final dynErr = validateDynamicFields(
      dynamicFields.where((f) => !f.hidden).toList(),
      _dynamicValues,
    );
    if (dynErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dynErr)));
      return;
    }
    if (_showBodyTypeSelect() && _bodyType.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите кузов')),
      );
      return;
    }

    final filterErr = ContentFilter.validateListingText(
      _titleCtrl.text.trim(),
      _descCtrl.text.trim(),
    );
    if (filterErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(filterErr)));
      return;
    }

    setState(() {
      _saving = true;
      _uploadFraction = 0;
    });
    _scrollToUploadProgress();
    try {
      final fields = buildAdCreatePayload(
        categorySlug: _categorySlug!,
        subcategorySlug: _leafSubcategorySlug!,
        subcategoryPath: _subPath,
        subcategoryRoots: _subRoots,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        city: _localityId!,
        priceType: _priceType,
        price: _priceCtrl.text.trim(),
        currency: 'TJS',
        tariffId: _tariffId.isEmpty ? null : _tariffId,
        dynamicValues: Map<String, String>.from(_dynamicValues),
        bodyType: _bodyType,
      );
      final res = await DastrassApi.instance.createAd(
        fields: fields,
        photos: _photos.map((e) => (bytes: e.bytes, filename: e.filename)).toList(),
        video: _video,
        onSendProgress: (sent, total) {
          if (total <= 0 || !mounted) return;
          setState(() => _uploadFraction = sent / total);
        },
      );
      if (!mounted) return;
      final id = '${res['id'] ?? ''}';
      if (id.isEmpty) throw ApiException('Нет id в ответе');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ваше объявление будет добавлено.')),
      );
      context.go('/profile');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'INSUFFICIENT_BALANCE') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        context.go('/profile');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadFraction = null;
        });
      }
    }
  }

  void _onAddAdSystemBack() {
    if (_categorySlug != null) {
      if (_subPath.isNotEmpty) {
        setState(() {
          _subPath = _subPath.sublist(0, _subPath.length - 1);
          _clearDynamicValues();
        });
        return;
      }
      setState(() {
        _categorySlug = null;
        _subPath = [];
        _clearDynamicValues();
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    final muted = theme.hintColor;
    final cardBg = theme.cardColor;
    final border = theme.dividerColor;

    if (!AuthService.instance.isAuthenticated) {
      return Center(
        child: Text('Войдите, чтобы добавить объявление', style: TextStyle(color: onBg)),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: onBg)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _bootstrap, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onAddAdSystemBack();
      },
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, kTabScrollBottomPadding),
      children: [
        if (_categorySlug == null) ...[
          _buildCategoryStepHead(theme, onBg, muted),
          const SizedBox(height: 16),
          if (_loading)
            _buildCategorySkeletonGrid()
          else if (_mainCats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Не удалось загрузить категории. Обновите страницу.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
            )
          else
            _buildCategoryGrid(),
        ] else ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAddAdIntroBlock(
                    theme: theme,
                    subtitle: 'Заполните поля и добавьте фотографии.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildForm(onBg, muted, cardBg, border),
        ],
      ],
    ),
    );
  }

  /// Сарлавҳаи қадами 1 — мисли `.add-ad-category-step-head`.
  Widget _buildCategoryStepHead(ThemeData theme, Color onBg, Color muted) {
    final light = theme.brightness == Brightness.light;
    final titleColor = light ? const Color(0xFF1A1F36) : Colors.white.withValues(alpha: 0.95);
    final subColor = light ? const Color(0x851A1F36) : Colors.white.withValues(alpha: 0.55);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Добавить объявление',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 25,
                height: 1.2,
                letterSpacing: -0.3,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Выберите категории',
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final cats = _mainCats;
    final rows = <Widget>[];

    for (var i = 0; i < cats.length; i += 3) {
      final chunk = cats.skip(i).take(3).toList();
      final isLonelyLast = chunk.length == 1 && i == cats.length - 1;

      if (isLonelyLast) {
        rows.add(
          Row(
            children: [
              const Spacer(),
              Expanded(
                child: AddAdCategoryTile(
                  category: chunk.first,
                  onTap: () => _pickCategory('${chunk.first['slug'] ?? ''}'),
                ),
              ),
              const Spacer(),
            ],
          ),
        );
      } else {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < 3; j++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: j == 0 ? 0 : 2.5, right: j == 2 ? 0 : 2.5),
                    child: j < chunk.length
                        ? AddAdCategoryTile(
                            category: chunk[j],
                            onTap: () => _pickCategory('${chunk[j]['slug'] ?? ''}'),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        );
      }

      if (i + 3 < cats.length) rows.add(const SizedBox(height: 8));
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(children: rows),
      ),
    );
  }

  Widget _buildCategorySkeletonGrid() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            for (var row = 0; row < 4; row++) ...[
              if (row > 0) const SizedBox(height: 8),
              Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: col == 0 ? 0 : 2.5, right: col == 2 ? 0 : 2.5),
                        child: const AddAdCategoryTileSkeleton(),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _refreshColorOptions() async {
    await ColorCatalog.instance.ensureLoaded();
    if (!mounted) return;
    final opts = ColorCatalog.instance.optionLabels;
    if (opts.isEmpty) return;
    setState(() => _colorOptions = opts);
  }

  void _pickCategory(String slug) {
    if (slug.isEmpty) return;
    unawaited(_refreshColorOptions());
    setState(() {
      _categorySlug = slug;
      _subPath = [];
      _clearDynamicValues();
    });
  }

  /// Сарлавҳа + зернавис — блоки ҷудо, матнҳои хурдтар.
  Widget _buildAddAdIntroBlock({
    required ThemeData theme,
    required String subtitle,
  }) {
    final light = theme.brightness == Brightness.light;
    final blockBg = light ? const Color(0xFFF6F8FB) : const Color(0xFF131B2E);
    final blockBorder = light ? const Color(0xFFE2E5EB) : const Color(0x33FFFFFF);
    final titleColor = light ? AppColors.textLight : Colors.white;
    final subColor = light ? theme.colorScheme.onSurface.withValues(alpha: 0.55) : const Color(0xFFB8C0D4);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: blockBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: blockBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Text(
              'Добавить объявление',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.25,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: subColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelectedBox(ThemeData theme, Color onBg, Color muted) {
    final light = theme.brightness == Brightness.light;
    final boxBorder = light ? const Color.fromRGBO(0, 91, 254, 0.18) : const Color(0x1FFFFFFF);
    final g0 = light ? const Color(0x0F005BFE) : const Color(0x19005BFE);
    final g1 = light ? const Color(0x05005BFE) : const Color(0x14005BFE);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: boxBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [g0, g1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    'КАТЕГОРИЯ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: light ? const Color(0xFF6C757D) : muted.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    _currentCat?['name']?.toString() ?? _categorySlug ?? '',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onBg),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              onPressed: () => setState(() {
                _categorySlug = null;
                _subPath = [];
              }),
              child: const Text('Изменить категорию'),
            ),
          ],
        ),
      ),
    );
  }

  String _slugToLabel(List<dynamic> options, String slug) {
    for (final raw in options) {
      final m = raw as Map<String, dynamic>;
      if ('${m['slug']}' == slug) return '${m['name']}';
    }
    return slug;
  }

  PopupProps<String> _select2PopupProps(ThemeData theme, String titleText) {
    return PopupProps.modalBottomSheet(
      showSearchBox: true,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            titleText,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      searchFieldProps: TextFieldProps(
        decoration: InputDecoration(
          hintText: 'Поиск...',
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          prefixIcon: const Icon(Icons.search, size: 22),
        ),
      ),
      modalBottomSheetProps: ModalBottomSheetProps(
        backgroundColor: theme.colorScheme.surface,
        showDragHandle: true,
      ),
    );
  }

  DropDownDecoratorProps _select2FieldDecoration(ThemeData theme, String hint) {
    final th = theme.inputDecorationTheme;
    return DropDownDecoratorProps(
      decoration: InputDecoration(
        hintText: hint,
        filled: th.filled,
        fillColor: th.fillColor,
        contentPadding: th.contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: th.border ?? OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: th.enabledBorder,
        focusedBorder: th.focusedBorder,
        disabledBorder: th.disabledBorder,
      ),
      baseStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
    );
  }

  Widget _levelSubDropdown(ThemeData theme, int levelIdx, List<dynamic> options, String hint) {
    String? initialVal() {
      if (_subPath.length <= levelIdx) return null;
      final v = _subPath[levelIdx];
      if (!options.any((raw) => '${(raw as Map)['slug']}' == v)) return null;
      return v;
    }

    return DropdownSearch<String>(
      key: ValueKey('sc${levelIdx}_${_categorySlug}_${_subPath.join('|')}'),
      selectedItem: initialVal(),
      enabled: options.isNotEmpty,
      items: (filter, _) async {
        final q = filter.trim().toLowerCase();
        final out = <String>[];
        for (final raw in options) {
          final m = raw as Map<String, dynamic>;
          final slug = '${m['slug']}';
          final name = '${m['name']}'.toLowerCase();
          if (q.isEmpty || name.contains(q) || slug.toLowerCase().contains(q)) {
            out.add(slug);
          }
        }
        return out;
      },
      itemAsString: (slug) => _slugToLabel(options, slug),
      onSelected: (v) => _handleSubcategoryLevelPick(levelIdx, v),
      popupProps: _select2PopupProps(theme, hint),
      decoratorProps: _select2FieldDecoration(theme, hint),
    );
  }

  Widget _buildSubcategoryDropdowns(ThemeData theme) {
    final roots = _subRoots ?? const <dynamic>[];
    final l1 = roots;
    final l2 = _subPath.isNotEmpty ? _catGetChildrenForPath(roots, [_subPath[0]]) : const <dynamic>[];
    final l3 = _subPath.length >= 2 ? _catGetChildrenForPath(roots, _subPath.take(2).toList()) : const <dynamic>[];

    final showL2 = _subPath.isNotEmpty && l2.isNotEmpty;
    final showL3Row = _subPath.length >= 2 && l3.isNotEmpty;
    final showBody = _showBodyTypeSelect();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _levelSubDropdown(theme, 0, l1, 'Выберите'),
        if (showL2) ...[
          const SizedBox(height: 10),
          if (showL3Row)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _levelSubDropdown(theme, 1, l2, 'Выберите')),
                const SizedBox(width: 10),
                Expanded(child: _levelSubDropdown(theme, 2, l3, 'Выберите')),
              ],
            )
          else
            _levelSubDropdown(theme, 1, l2, 'Выберите'),
        ],
        if (showBody) ...[
          const SizedBox(height: 10),
          DropdownSearch<String>(
            key: ValueKey('body_$_bodyType'),
            selectedItem: _bodyType.isEmpty ? null : _bodyType,
            items: (filter, _) async {
              final q = filter.trim().toLowerCase();
              return PassengerCarConfig.bodyTypes
                  .where((n) => q.isEmpty || n.toLowerCase().contains(q))
                  .toList();
            },
            onSelected: (v) => setState(() => _bodyType = v ?? ''),
            popupProps: _select2PopupProps(theme, 'Выберите кузов'),
            decoratorProps: _select2FieldDecoration(theme, 'Выберите кузов'),
          ),
        ],
      ],
    );
  }

  Widget _buildDynamicField(ThemeData theme, Color onBg, AdDynamicField field) {
    final label = '${field.label}${field.required ? ' *' : ''}';
    if (field.type == AdFieldType.select) {
      final options = field.key == 'color' && field.options.isEmpty
          ? (_colorOptions.isNotEmpty ? _colorOptions : defaultColorOptionLabels())
          : field.options;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
          const SizedBox(height: 6),
          DropdownSearch<String>(
            key: ValueKey('dyn_${field.key}_${_leafSubcategorySlug}_${_dynamicValues[field.key]}'),
            selectedItem: (_dynamicValues[field.key] ?? '').isEmpty ? null : _dynamicValues[field.key],
            items: (filter, _) async {
              final q = filter.trim().toLowerCase();
              return options
                  .where((o) => q.isEmpty || o.toLowerCase().contains(q))
                  .toList();
            },
            onSelected: (v) => setState(() => _dynamicValues[field.key] = v ?? ''),
            popupProps: _select2PopupProps(theme, 'Выберите из списка...'),
            decoratorProps: _select2FieldDecoration(theme, 'Выберите из списка...'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('dyn_${field.key}_${_leafSubcategorySlug}'),
          initialValue: _dynamicValues[field.key] ?? '',
          keyboardType: field.type == AdFieldType.number ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: onBg),
          decoration: InputDecoration(hintText: field.placeholder.isEmpty ? null : field.placeholder),
          onChanged: (v) => _dynamicValues[field.key] = v,
        ),
      ],
    );
  }

  Widget _buildDynamicFieldsSections(ThemeData theme, Color onBg) {
    if (_leafSubcategorySlug == null) return const SizedBox.shrink();
    final all = _currentDynamicFields().where((f) => !f.hidden).toList();
    if (all.isEmpty) return const SizedBox.shrink();

    final regular = all.where((f) => f.section == AdFieldSection.regular).toList();
    final characteristics = all.where((f) => f.section == AdFieldSection.characteristics).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (regular.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...regular.expand((f) => [
                _buildDynamicField(theme, onBg, f),
                const SizedBox(height: 12),
              ]),
        ],
        if (characteristics.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Характеристика', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: onBg)),
          const SizedBox(height: 12),
          ...characteristics.expand((f) => [
                _buildDynamicField(theme, onBg, f),
                const SizedBox(height: 12),
              ]),
        ],
      ],
    );
  }

  Widget _buildCurrencyLabel(ThemeData theme, Color onBg) {
    return SizedBox(
      width: 56,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            'смн',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(Color onBg, Color muted, Color cardBg, Color border) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCategorySelectedBox(theme, onBg, muted),
                  const SizedBox(height: 16),
                  Text('Подкатегория *', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
                  const SizedBox(height: 8),
                  _buildSubcategoryDropdowns(theme),
                  const SizedBox(height: 16),
                  Text('Заголовок *', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleCtrl,
                    style: TextStyle(color: onBg),
                    decoration: InputDecoration(hintText: _titlePlaceholder()),
                    validator: (v) => (v == null || v.trim().length < 3) ? 'Минимум 3 символа' : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Цена${_priceType != 'negotiable' ? ' *' : ''}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: onBg),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceCtrl,
                          enabled: _priceType == 'fixed',
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: onBg),
                          decoration: const InputDecoration(hintText: '50000'),
                          validator: (v) {
                            if (_priceType != 'fixed') return null;
                            if (v == null || v.trim().isEmpty) return 'Укажите цену';
                            if (num.tryParse(v.trim()) == null) return 'Некорректная цена';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildCurrencyLabel(theme, onBg),
                    ],
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    value: _priceType == 'negotiable',
                    onChanged: (v) => setState(() {
                      _priceType = v == true ? 'negotiable' : 'fixed';
                      if (v == true) _priceCtrl.clear();
                    }),
                    title: Text('Договорная', style: TextStyle(color: onBg, fontWeight: FontWeight.w500)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (_priceType == 'negotiable')
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => setState(() => _priceType = 'fixed'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        child: const Text('Указать цену'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Место / район *', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
                  const SizedBox(height: 6),
                  DropdownSearch<String>(
                    key: ValueKey('loc_${_localities.length}_${_localityId ?? ''}'),
                    selectedItem: _localityId != null && _localities.any((e) => '${e['id']}' == _localityId)
                        ? _localityId
                        : null,
                    enabled: _localities.isNotEmpty,
                    items: (filter, _) async {
                      final q = filter.trim().toLowerCase();
                      final out = <String>[];
                      for (final e in selectableLocalities(_localities)) {
                        final id = '${e['id']}';
                        final label = localitySelectLabel(e).toLowerCase();
                        if (q.isEmpty || label.contains(q) || id.contains(q)) {
                          out.add(id);
                        }
                      }
                      return out;
                    },
                    itemAsString: (id) {
                      for (final e in _localities) {
                        if ('${e['id']}' == id) return localitySelectLabel(e);
                      }
                      return id;
                    },
                    onSelected: (v) => setState(() => _localityId = v),
                    validator: (v) => v == null || v.isEmpty ? 'Выберите' : null,
                    popupProps: _select2PopupProps(theme, 'Выберите'),
                    decoratorProps: _select2FieldDecoration(theme, 'Выберите'),
                  ),
                  _buildDynamicFieldsSections(theme, onBg),
                  const SizedBox(height: 16),
                  Text('Описание *', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descCtrl,
                    minLines: 4,
                    maxLines: 8,
                    style: TextStyle(color: onBg),
                    decoration: const InputDecoration(
                      hintText: 'Опишите товар или услугу, состояние, характеристики и условия.',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().length < 10) ? 'Минимум 10 символов' : null,
                  ),
                  if (_tariffs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Тариф', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
                    const SizedBox(height: 6),
                    RadioGroup<String>(
                      groupValue: _tariffId,
                      onChanged: (v) => setState(() => _tariffId = v ?? ''),
                      child: Column(
                        children: [
                          ..._tariffs.map((raw) {
                            final t = raw as Map<String, dynamic>;
                            final id = '${t['id'] ?? ''}';
                            final name = '${t['name'] ?? ''}';
                            final price = '${t['price'] ?? ''}';
                            final top = t['is_top'] == true;
                            return RadioListTile<String>(
                              title: Text(
                                price == '0' || price.isEmpty ? name : '$name — $price TJS',
                                style: TextStyle(color: onBg),
                              ),
                              subtitle: top
                                  ? Text('ТОП', style: TextStyle(color: AppColors.primary, fontSize: 12))
                                  : null,
                              value: id,
                              contentPadding: EdgeInsets.zero,
                            );
                          }),
                          RadioListTile<String>(
                            title: Text('Без платного тарифа', style: TextStyle(color: onBg)),
                            value: '',
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Фотографии (до 10) *', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
                  const SizedBox(height: 6),
                  Text(
                    'JPG, PNG, WebP и др. На сервере сохраняются как WebP.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _photoSlotsLeft <= 0 || _saving ? null : _pickPhotosGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Галерея'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _photoSlotsLeft <= 0 || _saving ? null : _pickPhotoCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Камера'),
                      ),
                    ],
                  ),
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _photos[i].bytes,
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (i == 0)
                                Positioned(
                                  left: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Основное',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton.filledTonal(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  onPressed: () => _removePhoto(i),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                bottom: 0,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.chevron_left, size: 20),
                                      onPressed: i == 0 ? null : () => _movePhoto(i, -1),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.chevron_right, size: 20),
                                      onPressed: i == _photos.length - 1 ? null : () => _movePhoto(i, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Видео (необязательно)', style: TextStyle(fontWeight: FontWeight.w600, color: onBg)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : _pickVideoGallery,
                        child: Text(_video == null ? 'Выбрать видео' : 'Заменить видео'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _video?.filename ?? 'MP4, WebM, MOV, M4V, до 200 МБ',
                          style: TextStyle(fontSize: 12, color: muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_video != null)
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  await LocalVideoPreviewHandle.close(_videoPreview);
                                  _videoPreview = null;
                                  setState(() => _video = null);
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  if (_saving && _video != null && _uploadFraction != null) ...[
                    const SizedBox(height: 10),
                    _buildUploadProgress(onBg, muted),
                  ],
                  if (_videoPreview != null && _videoPreview!.controller.value.isInitialized) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: Colors.black,
                        child: AspectRatio(
                          aspectRatio: _videoPreview!.controller.value.aspectRatio > 0
                              ? _videoPreview!.controller.value.aspectRatio
                              : 16 / 9,
                          child: AnimatedBuilder(
                            animation: _videoPreview!.controller,
                            builder: (context, _) {
                              final c = _videoPreview!.controller;
                              return Stack(
                                alignment: Alignment.center,
                                fit: StackFit.expand,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.contain,
                                    child: SizedBox(
                                      width: c.value.size.width,
                                      height: c.value.size.height,
                                      child: VideoPlayer(c),
                                    ),
                                  ),
                                  Material(
                                    color: Colors.black26,
                                    type: MaterialType.transparency,
                                    child: InkWell(
                                      onTap: () async {
                                        if (c.value.isPlaying) {
                                          await c.pause();
                                        } else {
                                          await c.play();
                                        }
                                        setState(() {});
                                      },
                                      child: Center(
                                        child: Icon(
                                          c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                          size: 56,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_saving && _uploadFraction != null) ...[
                    const SizedBox(height: 12),
                    _buildUploadProgress(onBg, muted),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? Text(
                            _uploadFraction != null
                                ? 'Загрузка ${(_uploadFraction! * 100).clamp(0, 100).toStringAsFixed(0)}%'
                                : 'Сохранение...',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                          )
                        : const Text(
                            'Добавить объявление',
                            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
