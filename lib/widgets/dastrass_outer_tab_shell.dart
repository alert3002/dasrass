import 'package:flutter/material.dart';

import 'dastrass_main_tab_navigation.dart';
import 'dastrass_mobile_tab_bar.dart';

/// Футер дар ҳамаи саҳифаҳо (як таблетка, 5px аз поён).
class DastrassOuterTabShell extends StatelessWidget {
  const DastrassOuterTabShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tabReserve = mobileTabBarBottomInset(context);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: tabReserve,
            child: child,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DastrassMobileTabBar(
              selectedIndex: mainTabIndexForLocation(location),
              onTab: (i) => goMainTab(context, i),
            ),
          ),
        ],
      ),
    );
  }
}
