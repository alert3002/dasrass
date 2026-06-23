import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/compare_store.dart';
import '../services/favorites_service.dart';
import '../services/favorites_store.dart';
import '../theme/app_theme.dart';
import 'dastrass_header_search.dart';
import '../theme/theme_controller.dart';
import 'dastrass_logo.dart';

/// Менюи чап — мисли `index.css` + [Layout.jsx]: дар темаи торик чун `html[data-theme="dark"] .mobile-drawer-*`,
/// дар равшан чун `.mobile-drawer-panel` / `.mobile-drawer-block` (сафед).
class DastrassAppDrawer extends StatefulWidget {
  const DastrassAppDrawer({super.key});

  @override
  State<DastrassAppDrawer> createState() => _DastrassAppDrawerState();
}

class _DastrassAppDrawerState extends State<DastrassAppDrawer> {
  final _searchCtrl = TextEditingController();
  int _favCount = 0;

  @override
  void initState() {
    super.initState();
    CompareStore.instance.addListener(_onExternal);
    FavoritesStore.instance.addListener(_onExternal);
    ThemeController.instance.addListener(_onExternal);
    _reloadFavorites();
    CompareStore.instance.hydrate();
    FavoritesStore.instance.hydrate();
  }

  @override
  void dispose() {
    CompareStore.instance.removeListener(_onExternal);
    FavoritesStore.instance.removeListener(_onExternal);
    ThemeController.instance.removeListener(_onExternal);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onExternal() {
    if (mounted) setState(() {});
  }

  Future<void> _reloadFavorites() async {
    try {
      final list = await FavoritesService.loadList();
      if (mounted) setState(() => _favCount = list.length);
    } catch (_) {
      if (mounted) setState(() => _favCount = FavoritesStore.instance.count);
    }
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final compareCount = CompareStore.instance.count;
    final themeCtrl = ThemeController.instance;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final panelBg = dark ? const Color(0xFF000000) : Colors.white;
    final sectionLabelColor =
        dark ? const Color.fromRGBO(255, 255, 255, 0.42) : const Color.fromRGBO(15, 23, 42, 0.45);
    final blockBg = dark ? const Color(0xFF1C1C1E) : const Color(0xFFEEF1F6);
    final blockBorder =
        dark ? const Color.fromRGBO(255, 255, 255, 0.06) : const Color.fromRGBO(15, 23, 42, 0.08);
    final linkText = dark ? const Color.fromRGBO(255, 255, 255, 0.92) : const Color(0xFF1A1F36);
    final linkIcon = dark ? const Color.fromRGBO(255, 255, 255, 0.82) : const Color(0xFF475569);
    final closeBg = dark ? const Color(0xFF252525) : const Color(0xFFEEF1F6);
    final closeBorder =
        dark ? const Color.fromRGBO(255, 255, 255, 0.06) : const Color.fromRGBO(15, 23, 42, 0.1);
    final closeIcon = dark ? const Color.fromRGBO(255, 255, 255, 0.92) : const Color(0xFF1A1F36);
    final themeTitle = dark ? Colors.white : const Color(0xFF1A1F36);
    final themeSub = dark ? const Color.fromRGBO(255, 255, 255, 0.5) : const Color.fromRGBO(15, 23, 42, 0.55);
    final segmentTrackBg = dark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E6EF);
    final segmentTrackBorder =
        dark ? const Color.fromRGBO(255, 255, 255, 0.08) : const Color.fromRGBO(15, 23, 42, 0.1);
    final segmentInactive = dark ? const Color.fromRGBO(255, 255, 255, 0.72) : const Color.fromRGBO(15, 23, 42, 0.65);
    final footBorder = dark ? const Color.fromRGBO(255, 255, 255, 0.08) : const Color.fromRGBO(15, 23, 42, 0.1);
    final footColor = dark ? const Color.fromRGBO(255, 255, 255, 0.55) : const Color.fromRGBO(15, 23, 42, 0.55);

    return Drawer(
      backgroundColor: panelBg,
      width: (MediaQuery.sizeOf(context).width * 0.85).clamp(280.0, 360.0),
      elevation: 0,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: DastrassLogo(
                    onTap: () {
                      _close();
                      context.go('/home');
                    },
                    height: 42,
                    maxWidth: 180,
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: closeBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: closeBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _close,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.close_rounded, color: closeIcon, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DastrassHeaderSearch(
              controller: _searchCtrl,
              beforeNavigate: _close,
            ),
            const SizedBox(height: 14),
            _sectionLabel('ОБЪЯВЛЕНИЯ', sectionLabelColor),
            const SizedBox(height: 6),
            _navBlock(
              blockBg: blockBg,
              blockBorder: blockBorder,
              children: [
                _link(Icons.home_rounded, 'Главная', linkText, linkIcon, () {
                  _close();
                  context.go('/home');
                }),
                _link(Icons.movie_creation_outlined, 'Reels', linkText, linkIcon, () {
                  _close();
                  context.push('/reels');
                }),
                _link(Icons.compare_arrows_rounded, 'Сравнение', linkText, linkIcon, () {
                  _close();
                  context.push('/favorites?tab=compare');
                }, badge: compareCount > 0 ? compareCount : null),
                _link(
                  _favCount > 0 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  'Избранное',
                  linkText,
                  linkIcon,
                  () {
                    _close();
                    context.go('/favorites');
                  },
                  badge: _favCount > 0 ? _favCount : null,
                ),
                _link(Icons.add_shopping_cart_rounded, 'Добавить объявление', linkText, linkIcon, () {
                  _close();
                  context.go('/add');
                }),
              ],
            ),
            const SizedBox(height: 14),
            _sectionLabel('ИНФОРМАЦИЯ', sectionLabelColor),
            const SizedBox(height: 6),
            _navBlock(
              blockBg: blockBg,
              blockBorder: blockBorder,
              children: [
                _link(Icons.info_outline_rounded, 'О dastrass', linkText, linkIcon, () {
                  _close();
                  context.push('/about');
                }),
                _link(Icons.description_outlined, 'Условия использования', linkText, linkIcon, () {
                  _close();
                  context.push('/terms');
                }),
                _link(Icons.shield_outlined, 'Конфиденциальность', linkText, linkIcon, () {
                  _close();
                  context.push('/privacy');
                }),
              ],
            ),
            const SizedBox(height: 14),
            _themeCard(
              themeCtrl: themeCtrl,
              cardBg: blockBg,
              cardBorder: blockBorder,
              themeTitle: themeTitle,
              themeSub: themeSub,
              segmentTrackBg: segmentTrackBg,
              segmentTrackBorder: segmentTrackBorder,
              segmentInactive: segmentInactive,
              footBorder: footBorder,
              footColor: footColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.08 * 16,
        ),
      ),
    );
  }

  Widget _navBlock({
    required Color blockBg,
    required Color blockBorder,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: blockBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: blockBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _link(
    IconData icon,
    String label,
    Color textColor,
    Color iconColor,
    VoidCallback onTap, {
    int? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF005BFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeCard({
    required ThemeController themeCtrl,
    required Color cardBg,
    required Color cardBorder,
    required Color themeTitle,
    required Color themeSub,
    required Color segmentTrackBg,
    required Color segmentTrackBorder,
    required Color segmentInactive,
    required Color footBorder,
    required Color footColor,
  }) {
    final light = themeCtrl.preference == ThemePref.light;
    final isDarkPref = themeCtrl.preference == ThemePref.dark;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Тема',
            style: TextStyle(
              color: themeTitle,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Сейчас: ${themeCtrl.labelRu}',
            style: TextStyle(
              color: themeSub,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: segmentTrackBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: segmentTrackBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _segmentBtn(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Светлая',
                    active: light,
                    inactiveColor: segmentInactive,
                    onTap: () => themeCtrl.setLight(),
                  ),
                ),
                Expanded(
                  child: _segmentBtn(
                    icon: Icons.dark_mode_outlined,
                    label: 'Тёмная',
                    active: isDarkPref,
                    inactiveColor: segmentInactive,
                    onTap: () => themeCtrl.setDark(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: footBorder),
          InkWell(
            onTap: () {
              _close();
              context.go('/profile');
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Все настройки темы',
                    style: TextStyle(
                      color: footColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: footColor.withValues(alpha: 0.75)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentBtn({
    required IconData icon,
    required String label,
    required bool active,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A4ACC),
                      Color(0xFF003A9E),
                    ],
                  )
                : null,
            color: active ? null : Colors.transparent,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.12),
                      offset: const Offset(0, -1),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : inactiveColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : inactiveColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
