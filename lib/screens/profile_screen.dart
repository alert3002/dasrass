import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/ad_format.dart';
import '../utils/network_error_message.dart';
import '../widgets/dastrass_mobile_tab_bar.dart';
import '../widgets/profile_page_head.dart';
import '../widgets/profile_my_ad_card.dart';

/// Статистика и кнопка «Добавить объявление» в профиле.
const _kProfileAdsStatsAndAddEnabled = true;

const _kProfileBalanceTabEnabled = false;

/// Профиль — мисли [frontend/src/pages/Profile.jsx]: данные, статистика, вкладки, карточки объявлений.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey _balanceSectionKey = GlobalKey();

  Map<String, dynamic>? _profile;
  List<dynamic> _ads = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _subscriptions = [];
  bool _subsLoading = false;

  bool _loading = true;
  String? _loadError;

  String _activeTab = 'ads';
  String _accountSubTab = 'settings';
  String? _balanceBanner;

  bool _editMode = false;
  final _fnCtrl = TextEditingController();
  final _lnCtrl = TextEditingController();
  String _dob = '';

  bool _saving = false;
  bool _adActionBusy = false;
  bool _avatarSaving = false;
  bool _deletingAccount = false;
  String? _formError;

  static final _dateFmt = DateFormat('dd.MM.yyyy');

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ОК'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AuthService.instance.setToken(null);
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_deletingAccount,
      builder: (ctx) => _DeleteAccountDialog(deleting: _deletingAccount),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await DastrassApi.instance.deleteAccount();
      await AuthService.instance.setToken(null);
      if (!mounted) return;
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  void dispose() {
    _fnCtrl.dispose();
    _lnCtrl.dispose();
    super.dispose();
  }

  String _formatDate(dynamic value) {
    if (value == null || '$value'.isEmpty) return '—';
    try {
      final s = '$value';
      final d = DateTime.tryParse(s);
      if (d == null) return s;
      return _dateFmt.format(d.toLocal());
    } catch (_) {
      return '$value';
    }
  }

  String _fullNameFromMap(Map<String, dynamic> p) {
    final fn = '${p['first_name'] ?? ''}'.trim();
    final ln = '${p['last_name'] ?? ''}'.trim();
    return '$fn $ln'.trim();
  }

  String _initials(Map<String, dynamic> p) {
    final fn = '${p['first_name'] ?? ''}'.trim();
    final ln = '${p['last_name'] ?? ''}'.trim();
    var initials = '${fn.isNotEmpty ? fn[0] : ''}${ln.isNotEmpty ? ln[0] : ''}'.trim().toUpperCase();
    if (initials.isEmpty) {
      final digits = '${p['phone'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
      initials = digits.length >= 2 ? digits.substring(digits.length - 2).toUpperCase() : (digits.isNotEmpty ? digits : '?');
    }
    return initials;
  }

  Future<void> _loadSubscriptions() async {
    if (!AuthService.instance.isAuthenticated) return;
    setState(() => _subsLoading = true);
    try {
      final list = await DastrassApi.instance.filterSubscriptions();
      if (!mounted) return;
      setState(() {
        _subscriptions = list;
        _subsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptions = [];
        _subsLoading = false;
      });
    }
  }

  Future<void> _load() async {
    if (!AuthService.instance.isAuthenticated) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final me = await DastrassApi.instance.me();
      if (me == null) {
        if (mounted) setState(() => _loadError = 'Не удалось загрузить профиль.');
        return;
      }
      List<dynamic> ads = [];
      List<Map<String, dynamic>> pay = [];
      try {
        ads = await DastrassApi.instance.myAds(limit: 200);
      } catch (_) {}
      try {
        pay = await DastrassApi.instance.myPayments();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _profile = me;
        _ads = ads;
        _payments = pay;
        _fnCtrl.text = _fullNameFromMap(me);
        _lnCtrl.text = '';
        final rawDob = me['date_of_birth'];
        _dob = rawDob != null && '$rawDob'.isNotEmpty ? '$rawDob'.split('T').first : '';
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadAds() async {
    final ads = await DastrassApi.instance.myAds(limit: 200);
    if (mounted) setState(() => _ads = ads);
  }

  Future<void> _reloadMe() async {
    final me = await DastrassApi.instance.me();
    if (me != null && mounted) setState(() => _profile = me);
  }

  Future<void> _pickAvatar() async {
    if (_avatarSaving) return;
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    setState(() => _avatarSaving = true);
    try {
      final bytes = await x.readAsBytes();
      final name = x.name.isNotEmpty ? x.name : 'avatar.jpg';
      final data = await DastrassApi.instance.uploadProfileAvatar(bytes, name);
      final url = '${data['avatar_url'] ?? ''}';
      if (mounted && _profile != null && url.isNotEmpty) {
        setState(() => _profile!['avatar_url'] = normalizeMediaUrl(url));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Фото профиля обновлено')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _avatarSaving = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _formError = null;
      _saving = true;
    });
    try {
      await DastrassApi.instance.updateProfile(
        firstName: _fnCtrl.text.trim(),
        lastName: '',
        dateOfBirth: _dob,
      );
      await _reloadMe();
      if (mounted) {
        setState(() => _editMode = false);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (e) {
      if (mounted) setState(() => _formError = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _adAction(String id, String action) async {
    if (_adActionBusy) return;
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Удалить объявление?'),
          content: const Text('Это действие нельзя отменить.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _adActionBusy = true);
    try {
      await DastrassApi.instance.myAdAction(id, action);
      await Future.wait([_reloadAds(), _reloadMe()]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Готово')));
      }
    } on ApiException catch (e) {
      if (e.code == 'INSUFFICIENT_BALANCE') {
        final needed = e.details?['needed'];
        final bal = e.details?['balance'];
        if (mounted) {
          setState(() {
            _balanceBanner =
                'Недостаточно средств для тарифа ТОП. Нужно ${needed ?? '?'} TJS, на балансе ${bal ?? '?'} TJS.';
          });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _adActionBusy = false);
    }
  }

  Future<void> _storyRequest(String id) async {
    if (_adActionBusy) return;
    setState(() => _adActionBusy = true);
    try {
      final res = await DastrassApi.instance.requestStory(id);
      if (!mounted) return;
      setState(() {
        _ads = _ads.map((raw) {
          final ad = Map<String, dynamic>.from(raw as Map);
          if ('${ad['id']}' != id) return ad;
          return {
            ...ad,
            'in_story': true,
            'story_expires_at': res['story_expires_at'],
            'story_next_request_at': res['story_next_request_at'],
            'story_seconds_left': res['story_seconds_left'],
            'story_retry_seconds': res['story_retry_seconds'],
          };
        }).toList();
      });
      final msg = '${res['message'] ?? ''}'.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'История добавлена в ленту' : msg)),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _adActionBusy = false);
    }
  }

  Future<void> _topup() async {
    final ctrl = TextEditingController(text: '50');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пополнение баланса'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Сумма, TJS'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Далее')),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;
    try {
      final data = await DastrassApi.instance.createTopup(amount);
      final payUrl = '${data['pay_url'] ?? ''}';
      if (payUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка на оплату не получена')));
        }
        return;
      }
      final uri = Uri.parse(payUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    final muted = const Color(0xFF8B949E);
    final cardBg = theme.cardColor;
    final border = theme.dividerColor;

    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (_loadError != null || _profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError ?? 'Ошибка', textAlign: TextAlign.center, style: TextStyle(color: onBg)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Повторить')),
              ],
            ),
          ),
        ),
      );
    }

    final p = _profile!;
    final bottomPad = _scrollBottomPadding(context);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const ProfilePageHead(),
                  const SizedBox(height: 8),
                  if (_balanceBanner != null && _balanceBanner!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFC9C9)),
                      ),
                      child: Text(
                        _balanceBanner!,
                        style: const TextStyle(color: Color(0xFFC92A2A), fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildTabsBar(onBg, muted, border),
                  const SizedBox(height: 12),
                  if (_activeTab == 'ads') ...[
                    if (_kProfileAdsStatsAndAddEnabled) ...[
                      _card(
                        cardBg: cardBg,
                        border: border,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        child: _buildStatsCard(p, onBg, muted),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildAdsTab(onBg, muted, cardBg, border, theme),
                  ],
                  if (_activeTab == 'account')
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: _buildAccountTab(p, onBg, muted, cardBg, border, theme),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Забо дар зери [DastrassMobileTabBar] + safe area.
  double _scrollBottomPadding(BuildContext context) => kTabScrollBottomPadding;

  Widget _card({
    required Widget child,
    required Color cardBg,
    required Color border,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.35)),
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _buildMyDataCard(Map<String, dynamic> p, Color onBg, Color muted, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Мои данные', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: onBg)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: Container(
                width: 72,
                height: 72,
                color: const Color(0xFF2D333B),
                alignment: Alignment.center,
                child: p['avatar_url'] != null && '${p['avatar_url']}'.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: normalizeMediaUrl('${p['avatar_url']}'),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Text(_initials(p), style: TextStyle(fontWeight: FontWeight.w800, color: onBg)),
                      )
                    : Text(_initials(p), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: onBg)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Фото в объявлениях показывается как фото продавца',
                    style: TextStyle(fontSize: 13, color: muted, height: 1.25),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _avatarSaving ? null : _pickAvatar,
                      child: Text(_avatarSaving ? 'Загрузка...' : 'Загрузить фото'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_editMode)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _fieldInput('ФИО', _fnCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _dobField(muted)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: Text(_saving ? 'Сохранение...' : 'Сохранить'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() {
                              _editMode = false;
                              _fnCtrl.text = _fullNameFromMap(p);
                              _lnCtrl.text = '';
                              final raw = p['date_of_birth'];
                              _dob = raw != null && '$raw'.isNotEmpty ? '$raw'.split('T').first : '';
                              _formError = null;
                            });
                          },
                    child: const Text('Отмена'),
                  ),
                ],
              ),
              if (_formError != null) ...[
                const SizedBox(height: 8),
                Text(_formError!, style: const TextStyle(color: Color(0xFFDC3545), fontSize: 13)),
              ],
            ],
          )
        else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _readOnlyField(
                      'ФИО',
                      _fullNameFromMap(p).isEmpty ? '—' : _fullNameFromMap(p),
                      onBg,
                      muted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _readOnlyField('Дата рождения', _formatDate(p['date_of_birth']), onBg, muted),
                  ),
                ],
              ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editMode = true),
                  child: const Text('Изменить'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleLogout,
                  child: const Text('Выйти'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _fieldInput(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dobField(Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Дата рождения', style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final init = DateTime.tryParse(_dob.isEmpty ? '' : _dob) ?? DateTime(now.year - 25, now.month, now.day);
              final d = await showDatePicker(
                context: context,
                initialDate: init,
                firstDate: DateTime(1940),
                lastDate: DateTime(now.year - 18, now.month, now.day),
              );
              if (d != null) {
                setState(() => _dob = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
              }
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_dob.isEmpty ? 'Выберите дату' : _dob),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyField(String label, String value, Color onBg, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: onBg)),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> p, Color onBg, Color muted) {
    final total = int.tryParse('${p['ads_total'] ?? 0}') ?? 0;
    final active = int.tryParse('${p['ads_active'] ?? 0}') ?? 0;
    final verified = int.tryParse('${p['ads_verified'] ?? 0}') ?? 0;
    final balance = num.tryParse('${p['balance'] ?? 0}') ?? 0;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        const spacing = 8.0;
        final cross = w < 520 ? 2 : 4;
        final tileW = (w - (cross - 1) * spacing) / cross;

        Widget tile(String label, String value, {VoidCallback? onTap}) {
          return SizedBox(
            width: tileW,
            child: _statTile(label, value, muted, onTap: onTap),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статистика объявлений',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: onBg),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                tile('Всего', '$total'),
                tile('Активные', '$active'),
                tile('Проверенные', '$verified'),
                if (_kProfileBalanceTabEnabled)
                  tile(
                    'Баланс, TJS',
                    NumberFormat.decimalPattern('ru_RU').format(balance),
                    onTap: () {
                      setState(() => _activeTab = 'balance');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final ctx = _balanceSectionKey.currentContext;
                        if (ctx != null) {
                          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _statTile(String label, String value, Color muted, {VoidCallback? onTap}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C2433) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: child),
    );
  }

  Color _profileTabInactiveColor() {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF6C757D)
        : Colors.white.withValues(alpha: 0.5);
  }

  Widget _profileUnderlineTab({
    required bool active,
    required String label,
    required VoidCallback onTap,
    required Color activeColor,
    double fontSize = 15,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  fontSize: fontSize,
                  height: 1.2,
                  color: active ? activeColor : _profileTabInactiveColor(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSubTab(String id, String label, Color onBg) {
    return _profileUnderlineTab(
      active: _accountSubTab == id,
      label: label,
      fontSize: 14.5,
      activeColor: onBg,
      onTap: () {
        setState(() => _accountSubTab = id);
        if (id == 'subscriptions') _loadSubscriptions();
      },
    );
  }

  Widget _buildAccountTab(
    Map<String, dynamic> p,
    Color onBg,
    Color muted,
    Color cardBg,
    Color border,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(cardBg: cardBg, border: border, child: _buildMyDataCard(p, onBg, muted, theme)),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFFE9ECEF)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          child: Row(
            children: [
              _buildAccountSubTab('subscriptions', 'Подписка', onBg),
              const SizedBox(width: 16),
              _buildAccountSubTab('settings', 'Настройки', onBg),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_accountSubTab == 'settings') _buildSettingsTab(onBg, muted, cardBg, border, theme),
        if (_accountSubTab == 'subscriptions') _buildSubscriptionsTab(onBg, muted, cardBg, border, theme),
        if (_kProfileBalanceTabEnabled) ...[
          const SizedBox(height: 16),
          _buildBalanceTab(p, onBg, muted, cardBg, border, theme),
        ],
      ],
    );
  }

  Widget _buildTabsBar(Color onBg, Color muted, Color border) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          _profileUnderlineTab(
            active: _activeTab == 'ads',
            label: 'Мои объявление',
            activeColor: onBg,
            onTap: () => setState(() => _activeTab = 'ads'),
          ),
          const SizedBox(width: 16),
          _profileUnderlineTab(
            active: _activeTab == 'account',
            label: 'Мой акаунт',
            activeColor: onBg,
            onTap: () {
              setState(() => _activeTab = 'account');
              _loadSubscriptions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdsTab(Color onBg, Color muted, Color cardBg, Color border, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_kProfileAdsStatsAndAddEnabled) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Мои объявления', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: onBg)),
              FilledButton.icon(
                onPressed: () => context.go('/add'),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Добавить объявление'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_ads.isEmpty)
          _card(
            cardBg: cardBg,
            border: border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('У вас ещё нет объявлений.', style: TextStyle(color: onBg)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.go('/add'),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Добавить объявление'),
                ),
              ],
            ),
          )
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  for (final raw in _ads) ...[
                    Builder(
                      builder: (context) {
                        final ad = Map<String, dynamic>.from(raw as Map);
                        final id = '${ad['id']}';
                        return Column(
                          children: [
                            ProfileMyAdCard(
                              ad: ad,
                              busy: _adActionBusy,
                              onEdit: () => context.push('/edit/ads/$id'),
                              onStory: () => _storyRequest(id),
                              onStoryInfo: () => ProfileStoryInfoDialog.show(context, ad),
                              onDelete: () => _adAction(id, 'delete'),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBalanceTab(Map<String, dynamic> p, Color onBg, Color muted, Color cardBg, Color border, ThemeData theme) {
    final balance = num.tryParse('${p['balance'] ?? 0}') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: _balanceSectionKey,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Баланс аккаунта', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: onBg)),
              const SizedBox(height: 8),
              Text(
                'Баланс используется для оплаты ТОП-тарифов и платных услуг размещения.',
                style: TextStyle(fontSize: 14, color: muted, height: 1.35),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Текущий баланс', style: TextStyle(fontSize: 13, color: muted)),
                      Text(
                        '${NumberFormat.decimalPattern('ru_RU').format(balance)} TJS',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ],
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                    onPressed: _topup,
                    child: const Text('Пополнить баланс'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Чтобы пополнить баланс, свяжитесь с поддержкой или менеджером площадки. После пополнения вы сможете активировать ТОП-тариф при добавлении объявления.',
                style: TextStyle(fontSize: 13, color: muted, height: 1.35),
              ),
              Divider(height: 28, color: border.withValues(alpha: 0.4)),
              Text('История операций', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: onBg)),
              const SizedBox(height: 8),
              if (_payments.isEmpty)
                Text('Платежей пока нет.', style: TextStyle(color: muted))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Дата')),
                      DataColumn(label: Text('Операция')),
                      DataColumn(label: Text('Метод оплаты')),
                      DataColumn(label: Text('Сумма'), numeric: true),
                      DataColumn(label: Text('Статус')),
                    ],
                    rows: _payments.map((pay) {
                      final st = '${pay['status'] ?? ''}';
                      final stLabel = st == 'done' ? 'Выполнено' : (st == 'pending' ? 'Ожидает оплаты' : 'Отменено');
                      final amt = num.tryParse('${pay['amount'] ?? 0}') ?? 0;
                      return DataRow(
                        cells: [
                          DataCell(Text(_formatDate(pay['date']), style: TextStyle(color: onBg))),
                          DataCell(Text('${pay['title'] ?? ''}', style: TextStyle(color: onBg))),
                          DataCell(Text('${pay['method'] ?? '—'}', style: TextStyle(color: onBg))),
                          DataCell(
                            Text(
                              '${NumberFormat.decimalPattern('ru_RU').format(amt)} ${pay['currency'] ?? ''}',
                              style: TextStyle(color: onBg),
                            ),
                          ),
                          DataCell(Text(stLabel, style: TextStyle(color: onBg))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(Color onBg, Color muted, Color cardBg, Color border, ThemeData theme) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final tc = ThemeController.instance;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border.withValues(alpha: 0.35)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2230) : const Color(0xFFF1F3F5),
                      border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.25))),
                    ),
                    child: Text('Тема', style: TextStyle(fontWeight: FontWeight.w700, color: onBg)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Сейчас активна: ${tc.labelRu}${tc.preference == ThemePref.auto ? ' · по времени в Душанбе' : ''}',
                          style: TextStyle(fontSize: 14, color: muted, height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        _themeOption(
                          title: 'Системная',
                          desc: 'Тема берётся из системных настроек устройства.',
                          active: tc.preference == ThemePref.system,
                          onTap: tc.setSystem,
                          onBg: onBg,
                          muted: muted,
                          border: border,
                        ),
                        const SizedBox(height: 8),
                        _themeOption(
                          title: 'Тёмная',
                          desc: 'Всегда тёмная тема.',
                          active: tc.preference == ThemePref.dark,
                          onTap: tc.setDark,
                          onBg: onBg,
                          muted: muted,
                          border: border,
                        ),
                        const SizedBox(height: 8),
                        _themeOption(
                          title: 'Светлая',
                          desc: 'Всегда светлая тема.',
                          active: tc.preference == ThemePref.light,
                          onTap: tc.setLight,
                          onBg: onBg,
                          muted: muted,
                          border: border,
                        ),
                        const SizedBox(height: 8),
                        _themeOption(
                          title: 'Авто (соат)',
                          desc: '08:00–19:00 светлая, 19:00–20:00 приглушённая, 20:00–08:00 тёмная (Душанбе).',
                          active: tc.preference == ThemePref.auto,
                          onTap: tc.setAuto,
                          onBg: onBg,
                          muted: muted,
                          border: border,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDeleteAccountSection(onBg, muted, cardBg, border),
          ],
        );
      },
    );
  }

  Widget _buildDeleteAccountSection(Color onBg, Color muted, Color cardBg, Color border) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC9C9).withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Удаление аккаунта',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: onBg),
          ),
          const SizedBox(height: 6),
          Text(
            'Все объявления будут скрыты, данные профиля и переписки удалены без возможности восстановления.',
            style: TextStyle(fontSize: 13.5, color: muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _deletingAccount ? null : _handleDeleteAccount,
            icon: _deletingAccount
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 20),
            label: Text(_deletingAccount ? 'Удаление...' : 'Удалить аккаунт'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC3545),
              side: const BorderSide(color: Color(0xFFFFB4B4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsTab(
    Color onBg,
    Color muted,
    Color cardBg,
    Color border,
    ThemeData theme,
  ) {
    return _buildSubscriptionsList(onBg, muted, cardBg, border);
  }

  Widget _buildSubscriptionsList(
    Color onBg,
    Color muted,
    Color cardBg,
    Color border,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A2230)
                  : const Color(0xFFF1F3F5),
              border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.25))),
            ),
            child: Text(
              'Подписки',
              style: TextStyle(fontWeight: FontWeight.w700, color: onBg),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Здесь все категории и фильтры, на которые вы подписались. При новых объявлениях придёт уведомление в раздел «Уведомления».',
                  style: TextStyle(fontSize: 14, color: muted, height: 1.35),
                ),
                const SizedBox(height: 12),
                if (_subsLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else if (_subscriptions.isEmpty)
                  Text('Подписок пока нет. На странице категории нажмите «Подписаться».', style: TextStyle(color: muted))
                else
                  ..._subscriptions.map((sub) {
                    final id = sub['id'] as int? ?? int.tryParse('${sub['id']}') ?? 0;
                    final title = '${sub['title'] ?? 'Подписка'}';
                    final active = sub['is_active'] == true;
                    final link = '${sub['link_url'] ?? ''}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: onBg)),
                          const SizedBox(height: 4),
                          Text(
                            active ? 'Активна' : 'Приостановлена',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (link.isNotEmpty)
                                TextButton(
                                  onPressed: () => context.go(link),
                                  child: const Text('Открыть поиск'),
                                ),
                              TextButton(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Отменить подписку?'),
                                      content: Text('Подписка «$title» будет удалена.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Нет'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Отменить подписку'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok != true || !mounted) return;
                                  await DastrassApi.instance.deleteFilterSubscription(id);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Подписка отменена')),
                                  );
                                  await _loadSubscriptions();
                                },
                                child: const Text('Отменить подписку', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeOption({
    required String title,
    required String desc,
    required bool active,
    required VoidCallback onTap,
    required Color onBg,
    required Color muted,
    required Color border,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppColors.primary : border.withValues(alpha: 0.4), width: active ? 2 : 1),
            color: active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: onBg)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(fontSize: 12.5, color: muted, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatelessWidget {
  const _DeleteAccountDialog({required this.deleting});

  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    final muted = const Color(0xFF8B949E);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_remove_outlined, color: Color(0xFFDC3545), size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Удалить аккаунт?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: onBg),
            ),
            const SizedBox(height: 10),
            Text(
              'Вы уверены, что хотите удалить аккаунт? Это действие нельзя отменить.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: muted, height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: deleting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Нет'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: deleting ? null : () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC3545),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Да, удалить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
