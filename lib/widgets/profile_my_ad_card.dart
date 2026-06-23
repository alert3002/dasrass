import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../utils/ad_format.dart';
import '../utils/locality_label.dart';
import '../utils/time_ago.dart';
import 'ad_no_photo_placeholder.dart';
import 'progressive_network_image.dart';

/// Карточка объявления в профиле — мисли [ProfileMyAdCard.jsx].
class ProfileMyAdCard extends StatelessWidget {
  const ProfileMyAdCard({
    super.key,
    required this.ad,
    required this.busy,
    required this.onEdit,
    required this.onStory,
    required this.onStoryInfo,
    required this.onDelete,
  });

  final Map<String, dynamic> ad;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onStory;
  final VoidCallback onStoryInfo;
  final VoidCallback onDelete;

  String _metaLine() {
    final city = shortLocalityLabel('${ad['location'] ?? ''}');
    final ago = formatTimeAgo('${ad['created_at'] ?? ''}');
    if (city.isNotEmpty && ago.isNotEmpty) return '$city · $ago';
    if (ago.isNotEmpty) return ago;
    if (city.isNotEmpty) return city;
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white.withValues(alpha: 0.92) : AppColors.textLight;
    final muted = isDark ? Colors.white.withValues(alpha: 0.62) : const Color(0x8C0F172A);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0x140F172A);

    final id = '${ad['id'] ?? ''}';
    final title = '${ad['title'] ?? ''}'.trim();
    final priceLabel = formatAdListingPrice(ad['price'], '${ad['currency'] ?? ''}');
    final views = (ad['views_count'] is num) ? (ad['views_count'] as num).toInt() : int.tryParse('${ad['views_count'] ?? 0}') ?? 0;
    final hasVideo = '${ad['video_url'] ?? ''}'.trim().isNotEmpty;
    final inStory = ad['in_story'] == true;
    final img = resolveAdImageUrl(ad);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0x0F0F172A),
            blurRadius: isDark ? 20 : 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Material(
                    color: const Color(0xFFE9ECEF),
                    child: InkWell(
                      onTap: id.isNotEmpty ? () => context.push('/ads/$id') : null,
                      child: img.isNotEmpty
                          ? AdListingImage(
                              imageUrl: img,
                              fit: BoxFit.cover,
                            )
                          : const AdNoPhotoPlaceholder(
                              borderRadius: BorderRadius.zero,
                              logoHeightFraction: 0.22,
                            ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dot(active: true),
                        const SizedBox(width: 5),
                        _dot(active: false),
                        const SizedBox(width: 5),
                        _dot(active: false),
                        const SizedBox(width: 5),
                        _dot(active: false),
                      ],
                    ),
                  ),
                  if (hasVideo)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('▶', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                title.isEmpty ? 'Без названия' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: titleColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      priceLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: titleColor,
                      ),
                    ),
                  ),
                  Text(
                    '# $id',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _metaLine(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: muted),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 15, color: muted.withValues(alpha: 0.95)),
                      const SizedBox(width: 4),
                      Text(
                        '$views',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted.withValues(alpha: 1)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      label: 'Изменить',
                      onPressed: busy ? null : onEdit,
                      style: _ActionBtnStyle.edit(isDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      label: inStory ? '✓ В сторис' : '+ Сторис',
                      onPressed: (busy && !inStory) ? null : (inStory ? onStoryInfo : onStory),
                      style: inStory ? _ActionBtnStyle.storyActive() : _ActionBtnStyle.story(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Удалить',
                      onPressed: busy ? null : onDelete,
                      style: _ActionBtnStyle.delete(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot({required bool active}) {
    return Container(
      width: active ? 7 : 6,
      height: active ? 7 : 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.primary : Colors.white.withValues(alpha: 0.55),
      ),
    );
  }
}

class _ActionBtnStyle {
  const _ActionBtnStyle({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  factory _ActionBtnStyle.edit(bool isDark) => _ActionBtnStyle(
        background: isDark ? Colors.transparent : Colors.white,
        foreground: isDark ? const Color(0xFF7AB0FF) : AppColors.primary,
        border: isDark ? const Color(0xFF7AB0FF) : AppColors.primary,
      );

  factory _ActionBtnStyle.story() => const _ActionBtnStyle(
        background: Color(0xFFFF4D8D),
        foreground: Colors.white,
        border: Color(0xFFFF4D8D),
      );

  factory _ActionBtnStyle.storyActive() => const _ActionBtnStyle(
        background: Color(0xFF16A34A),
        foreground: Colors.white,
        border: Color(0xFF16A34A),
      );

  factory _ActionBtnStyle.delete() => const _ActionBtnStyle(
        background: Color(0xFFE53935),
        foreground: Colors.white,
        border: Color(0xFFE53935),
      );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final VoidCallback? onPressed;
  final _ActionBtnStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: style.border, width: 1.5),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: onPressed == null ? style.foreground.withValues(alpha: 0.55) : style.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Модалка «История активна» — мисли [ProfileStoryInfoModal.jsx].
class ProfileStoryInfoDialog extends StatefulWidget {
  const ProfileStoryInfoDialog({super.key, required this.ad});

  final Map<String, dynamic> ad;

  static Future<void> show(BuildContext context, Map<String, dynamic> ad) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ProfileStoryInfoDialog(ad: ad),
    );
  }

  @override
  State<ProfileStoryInfoDialog> createState() => _ProfileStoryInfoDialogState();
}

class _ProfileStoryInfoDialogState extends State<ProfileStoryInfoDialog> {
  late int _retryLeft;

  @override
  void initState() {
    super.initState();
    _retryLeft = _secondsLeft();
    if (_retryLeft > 0) {
      Future.doWhile(() async {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return false;
        setState(() => _retryLeft = _secondsLeft());
        return _retryLeft > 0;
      });
    }
  }

  int _secondsLeft() {
    final iso = '${widget.ad['story_next_request_at'] ?? ''}';
    if (iso.isNotEmpty) {
      final dt = DateTime.tryParse(iso);
      if (dt != null) {
        return (dt.difference(DateTime.now()).inSeconds).clamp(0, 1 << 30);
      }
    }
    final fallback = (widget.ad['story_retry_seconds'] as num?)?.toInt() ??
        int.tryParse('${widget.ad['story_retry_seconds'] ?? 0}') ??
        0;
    return fallback.clamp(0, 1 << 30);
  }

  String _formatDuration(int seconds) {
    final s = seconds.clamp(0, 1 << 30);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final parts = <String>[];
    if (h > 0) parts.add('$h ч');
    if (m > 0 || h > 0) parts.add('$m мин');
    parts.add('$sec сек');
    return parts.join(' ');
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    final local = dt.toLocal();
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    final m = months[(local.month - 1).clamp(0, 11)];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} $m, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = '${widget.ad['title'] ?? ''}'.trim();
    final id = '${widget.ad['id'] ?? ''}';
    final canRetry = _retryLeft <= 0;
    final nextAt = '${widget.ad['story_next_request_at'] ?? ''}';

    final titleColor = isDark ? Colors.white.withValues(alpha: 0.95) : AppColors.textLight;
    final muted = isDark ? Colors.white.withValues(alpha: 0.62) : const Color(0xFF6C757D);
    final hintColor = isDark ? Colors.white.withValues(alpha: 0.62) : const Color(0xFF868E96);
    final dialogBg = isDark ? const Color(0xFF1C2433) : Colors.white;
    final rowBg = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF8F9FA);
    final timerColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark ? BorderSide(color: Colors.white.withValues(alpha: 0.1)) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'История активна',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: titleColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Объявление «${title.isEmpty ? '#$id' : title}» сейчас в ленте историй.',
              style: TextStyle(fontSize: 14.5, height: 1.45, color: muted),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: rowBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Снова добавить в истории',
                      style: TextStyle(fontSize: 12.5, color: muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canRetry ? 'сейчас можно' : _formatDuration(_retryLeft),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: timerColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (!canRetry) ...[
                      const SizedBox(height: 4),
                      Text(
                        'с ${_formatDateTime(nextAt)}',
                        style: TextStyle(fontSize: 13, color: hintColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Историю можно публиковать не чаще 1 раза в 24 часа для одного объявления.',
              style: TextStyle(fontSize: 13, height: 1.4, color: hintColor),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
