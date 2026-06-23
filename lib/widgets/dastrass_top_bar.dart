import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'dastrass_logo.dart';

/// Верхняя полоса: logo1.jpg + колокол (меню ва Reels танҳо дар таб-бар).
class DastrassTopBar extends StatelessWidget {
  const DastrassTopBar({
    super.key,
    this.onCloseInsteadOfMenu,
    this.notificationCount = 0,
    this.notificationsHighlight = false,
  });

  /// Дар `/login`: тугмаи × барои баргашт.
  final VoidCallback? onCloseInsteadOfMenu;
  final int notificationCount;
  /// Дар `/push`: ҳалқаи сафед атрофи колокол.
  final bool notificationsHighlight;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final onBar = light ? AppColors.textLight : Colors.white;
    final softBtnBg = light ? Colors.white : const Color(0x14FFFFFF);
    final softBtnBorder = light ? const Color(0x240F172A) : const Color(0x24FFFFFF);

    return Row(
      children: [
        if (onCloseInsteadOfMenu != null) ...[
          Material(
            color: softBtnBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
              side: BorderSide(color: softBtnBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onCloseInsteadOfMenu,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.close_rounded, color: onBar, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        DastrassLogo(onTap: () => context.go('/home'), height: 38, maxWidth: 140),
        const Spacer(),
        _BellWithBadge(
          count: notificationCount,
          ring: notificationsHighlight,
          iconColor: onBar,
          light: light,
        ),
      ],
    );
  }
}

class _BellWithBadge extends StatelessWidget {
  const _BellWithBadge({
    required this.count,
    required this.ring,
    required this.iconColor,
    required this.light,
  });

  final int count;
  final bool ring;
  final Color iconColor;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final bell = Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: Icon(Icons.notifications_none_rounded, color: iconColor, size: 24),
          tooltip: 'Уведомления',
          onPressed: () => context.push('/push'),
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );

    if (!ring) return bell;

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: light ? const Color(0x550F172A) : Colors.white.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: bell,
    );
  }
}
