import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dastrass_app_drawer.dart';
import 'dastrass_home_app_bar.dart';
import 'drawer_scaffold_scope.dart';
class DastrassTabShell extends StatefulWidget {
  const DastrassTabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<DastrassTabShell> createState() => _DastrassTabShellState();
}

class _DastrassTabShellState extends State<DastrassTabShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final showSearchRow = path == '/home';
    final hideHeader = !showSearchRow;

    return DrawerScaffoldScope(
      scaffoldKey: _scaffoldKey,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: path == '/home' || hideHeader ? null : const DastrassAppDrawer(),
        drawerEnableOpenDragGesture: path != '/home' && !hideHeader,
        appBar: hideHeader
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(DastrassHomeAppBar.heightFor(showSearchRow: showSearchRow)),
                child: DastrassHomeAppBar(
                  scaffoldKey: _scaffoldKey,
                  showSearchRow: showSearchRow,
                ),
              ),
        body: hideHeader
            ? SafeArea(bottom: false, child: widget.navigationShell)
            : widget.navigationShell,
      ),
    );
  }
}
