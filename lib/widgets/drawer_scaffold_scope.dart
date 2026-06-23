import 'package:flutter/material.dart';

/// [GlobalKey] барои [Scaffold]-и беруна (дар [DastrassTabShell]), то AppBar-и дохил [openDrawer]-ро кушояд.
class DrawerScaffoldScope extends InheritedWidget {
  const DrawerScaffoldScope({
    super.key,
    required this.scaffoldKey,
    required super.child,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;

  static GlobalKey<ScaffoldState> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DrawerScaffoldScope>();
    assert(scope != null, 'DrawerScaffoldScope not found');
    return scope!.scaffoldKey;
  }

  @override
  bool updateShouldNotify(DrawerScaffoldScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey;
}
