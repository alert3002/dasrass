import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../services/message_unread_hub.dart';
import '../theme/app_theme.dart';
import 'dastrass_header_home_style.dart';
import 'dastrass_header_search.dart';

/// AppBar: танҳо дар `/home` — ҷустуҷӯ + паёмҳо (бе лого ва push).
class DastrassHomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  const DastrassHomeAppBar({
    super.key,
    required this.scaffoldKey,
    this.onCloseInsteadOfMenu,
    this.showSearchRow = true,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback? onCloseInsteadOfMenu;
  final bool showSearchRow;

  static const double topBarOnlyHeight = 52;

  static double heightFor({required bool showSearchRow, bool closeOnly = false}) {
    if (showSearchRow) {
      return DastrassHeaderHomeStyle.searchHeight +
          DastrassHeaderHomeStyle.headerPadTop +
          DastrassHeaderHomeStyle.headerPadBottom;
    }
    if (closeOnly) return topBarOnlyHeight;
    return 0;
  }

  @override
  Size get preferredSize => Size.fromHeight(heightFor(showSearchRow: showSearchRow, closeOnly: onCloseInsteadOfMenu != null));

  @override
  State<DastrassHomeAppBar> createState() => _DastrassHomeAppBarState();
}

class _DastrassHomeAppBarState extends State<DastrassHomeAppBar> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showSearchRow) {
      if (widget.onCloseInsteadOfMenu == null) {
        return const SizedBox.shrink();
      }
      final light = Theme.of(context).brightness == Brightness.light;
      final onBar = light ? AppColors.textLight : Colors.white;
      final softBtnBg = light ? Colors.white : const Color(0x14FFFFFF);
      final softBtnBorder = light ? const Color(0x240F172A) : const Color(0x24FFFFFF);

      return DecoratedBox(
        decoration: BoxDecoration(
          color: light ? AppColors.headerBarLight : AppColors.headerBar,
        ),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: softBtnBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: BorderSide(color: softBtnBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onCloseInsteadOfMenu,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.close_rounded, color: onBar, size: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final light = Theme.of(context).brightness == Brightness.light;
    final bg = light ? DastrassHeaderHomeStyle.headerBg : AppColors.headerBar;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: light
            ? const Border(bottom: BorderSide(color: DastrassHeaderHomeStyle.headerBorder))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DastrassHeaderHomeStyle.headerPadH,
              DastrassHeaderHomeStyle.headerPadTop,
              DastrassHeaderHomeStyle.headerPadH,
              DastrassHeaderHomeStyle.headerPadBottom,
            ),
            child: ListenableBuilder(
              listenable: MessageUnreadHub.instance,
              builder: (context, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: DastrassHeaderSearch(controller: _searchCtrl, homeStyle: true)),
                  const SizedBox(width: DastrassHeaderHomeStyle.rowGap),
                  _HeaderMessagesButton(unread: MessageUnreadHub.instance.count),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderMessagesButton extends StatelessWidget {
  const _HeaderMessagesButton({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final iconColor = light ? DastrassHeaderHomeStyle.iconInk : Colors.white.withValues(alpha: 0.92);

    return SizedBox(
      width: DastrassHeaderHomeStyle.messagesBtnSize,
      height: DastrassHeaderHomeStyle.messagesBtnSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/messages'),
              customBorder: const CircleBorder(),
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.commentDots,
                  size: DastrassHeaderHomeStyle.messagesIconSize,
                  color: iconColor,
                ),
              ),
            ),
          ),
          if (unread > 0)
            const Positioned(
              left: 5,
              top: 7,
              child: _MessagesUnreadDot(),
            ),
        ],
      ),
    );
  }
}

class _MessagesUnreadDot extends StatelessWidget {
  const _MessagesUnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: DastrassHeaderHomeStyle.unreadDot,
        shape: BoxShape.circle,
      ),
    );
  }
}
