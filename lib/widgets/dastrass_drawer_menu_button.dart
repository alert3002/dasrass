import 'package:flutter/material.dart';

import 'drawer_scaffold_scope.dart';

/// Кнопка меню чап — [Drawer]-и [DastrassTabShell]-ро мекушояд.
class DastrassDrawerMenuButton extends StatelessWidget {
  const DastrassDrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Меню',
      onPressed: () {
        DrawerScaffoldScope.of(context).currentState?.openDrawer();
      },
    );
  }
}
