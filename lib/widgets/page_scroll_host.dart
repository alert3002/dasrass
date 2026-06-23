import 'package:flutter/material.dart';

import '../utils/app_scroll_reset.dart';

/// [PrimaryScrollController] для экрана + регистрация в [AppScrollReset].
class PageScrollHost extends StatefulWidget {
  const PageScrollHost({
    super.key,
    required this.routeKey,
    required this.child,
  });

  final String routeKey;
  final Widget child;

  @override
  State<PageScrollHost> createState() => _PageScrollHostState();
}

class _PageScrollHostState extends State<PageScrollHost> {
  late final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    AppScrollReset.instance.register(widget.routeKey, _controller);
  }

  @override
  void didUpdateWidget(covariant PageScrollHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeKey != widget.routeKey) {
      AppScrollReset.instance.unregister(oldWidget.routeKey, _controller);
      AppScrollReset.instance.register(widget.routeKey, _controller);
    }
  }

  @override
  void dispose() {
    AppScrollReset.instance.unregister(widget.routeKey, _controller);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _controller,
      child: widget.child,
    );
  }
}
