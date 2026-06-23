import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _kTabSemantics = ['Главная', 'Reels', 'Добавить', 'Избранное', 'Профиль'];

/// Фосилаи матн/тугма аз болои футер дар Reels.
const kReelsContentBottomGap = 10.0;

/// Фосилаи холӣ аз поёни экран то футер (0 = пурра ба поён).
const kMobileTabBarBottomGap = 0.0;

/// Padding болои иконкаҳои футер.
const kMobileTabBarTopPadding = 1.0;

/// Баландии футер-меню.
const kMobileTabBarHeight = 38.0;

/// Андозаи иконкаҳои футер.
const kMobileTabBarIconSize = 30.0;

/// Padding поён дар ListView-ҳои табҳо — футер аллакай дар [DastrassOuterTabShell] ҷудо шудааст.
const kTabScrollBottomPadding = 0.0;

/// Баландии минтақаи футер (барои [DastrassOuterTabShell]).
double mobileTabBarBottomInset(BuildContext context) {
  return kMobileTabBarTopPadding +
      kMobileTabBarBottomGap +
      MediaQuery.paddingOf(context).bottom +
      kMobileTabBarHeight;
}

/// Нижняя навигация — мисли [frontend/src/components/Layout.jsx] `.mobile-tabbar`.
class DastrassMobileTabBar extends StatelessWidget {
  const DastrassMobileTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTab,
  });

  final int? selectedIndex;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final light = Theme.of(context).brightness == Brightness.light;
    final barBg = light ? const Color(0xFAFFFFFF) : const Color(0xFA0A0F1C);
    final barBorder = light ? const Color(0x38000000) : const Color(0x2EFFFFFF);

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: barBg,
          border: Border(
            top: BorderSide(color: barBorder),
          ),
          boxShadow: [
            BoxShadow(
              color: (light ? Colors.black : Colors.black).withValues(alpha: light ? 0.06 : 0.28),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: kMobileTabBarTopPadding,
            bottom: kMobileTabBarBottomGap + safeBottom,
          ),
          child: SizedBox(
            height: kMobileTabBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: List.generate(5, (i) {
                  final selected = selectedIndex != null && selectedIndex == i;
                  return Expanded(
                    child: _TabItem(
                      index: i,
                      semanticsLabel: _kTabSemantics[i],
                      selected: selected,
                      isLight: light,
                      onTap: () => onTab(i),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.index,
    required this.semanticsLabel,
    required this.selected,
    required this.isLight,
    required this.onTap,
  });

  final int index;
  final String semanticsLabel;
  final bool selected;
  final bool isLight;
  final VoidCallback onTap;

  Color _activeColor() => isLight ? AppColors.primary : const Color(0xFF7AB0FF);

  Color _inactiveColor() => isLight
      ? const Color(0xFF111827).withValues(alpha: 0.88)
      : Colors.white.withValues(alpha: 0.88);

  IconData _icon() {
    switch (index) {
      case 0:
        return Icons.home_outlined;
      case 1:
        return Icons.play_arrow_outlined;
      case 2:
        return Icons.add;
      case 3:
        return Icons.favorite_border;
      case 4:
        return Icons.person_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeColor();
    final inactive = _inactiveColor();
    final iconColor = selected ? active : inactive;

    return Semantics(
      button: true,
      label: semanticsLabel,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: kMobileTabBarHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(_icon(), size: kMobileTabBarIconSize, color: iconColor),
              if (selected)
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: active,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
