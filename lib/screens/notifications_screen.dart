import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../services/notification_unread_hub.dart';
import '../services/notifications_local_store.dart';
import '../theme/app_theme.dart';
import '../widgets/dastrass_app_drawer.dart';

/// Саҳифаи «Уведомления» — мисли [frontend/src/pages/Push.jsx].
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _serverItems = [];
  bool _loadingServer = false;

  @override
  void initState() {
    super.initState();
    NotificationsLocalStore.instance.addListener(_onStore);
    AuthService.instance.addListener(_onAuth);
    _loadServer();
  }

  @override
  void dispose() {
    NotificationsLocalStore.instance.removeListener(_onStore);
    AuthService.instance.removeListener(_onAuth);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _onAuth() {
    _loadServer();
  }

  Future<void> _loadServer() async {
    if (!AuthService.instance.isAuthenticated) {
      if (mounted) setState(() => _serverItems = []);
      return;
    }
    if (mounted) setState(() => _loadingServer = true);
    try {
      final list = await DastrassApi.instance.notificationsList();
      if (mounted) setState(() => _serverItems = list);
    } catch (_) {
      if (mounted) setState(() => _serverItems = []);
    } finally {
      if (mounted) setState(() => _loadingServer = false);
    }
  }

  List<Map<String, dynamic>> get _merged {
    final local = NotificationsLocalStore.instance.items;
    if (!AuthService.instance.isAuthenticated) return List.from(local);
    return [..._serverItems, ...local];
  }

  static bool _isLocalId(dynamic id) => id != null && id.toString().contains('_');

  Future<void> _markAllRead() async {
    await NotificationsLocalStore.instance.markAllRead();
    if (AuthService.instance.isAuthenticated) {
      try {
        await DastrassApi.instance.notificationsMarkAllRead();
        await _loadServer();
      } catch (_) {}
    }
    await NotificationUnreadHub.instance.refresh();
    if (mounted) setState(() {});
  }

  Future<void> _clearLocal() async {
    await NotificationsLocalStore.instance.clear();
    await NotificationUnreadHub.instance.refresh();
    if (mounted) setState(() {});
  }

  Future<void> _onRowTap(Map<String, dynamic> n) async {
    if (!_isLocalId(n['id']) && n['read'] != true) {
      try {
        final id = n['id'];
        final pk = id is int ? id : int.tryParse('$id');
        if (pk != null) {
          await DastrassApi.instance.notificationMarkRead(pk);
          await _loadServer();
          await NotificationUnreadHub.instance.refresh();
          if (mounted) setState(() {});
        }
      } catch (_) {}
    }
    if (!mounted) return;
    _showDetailDialog(n);
  }

  String _formatWhen(String? value) {
    if (value == null || value.isEmpty) return '';
    try {
      final d = DateTime.parse(value).toLocal();
      return DateFormat('dd.MM.yyyy, HH:mm', 'ru').format(d);
    } catch (_) {
      return value;
    }
  }

  Future<void> _openLink(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  void _showDetailDialog(Map<String, dynamic> n) {
    final title = (n['title'] as String?)?.trim().isNotEmpty == true
        ? n['title'] as String
        : 'Уведомление';
    final msg = '${n['message'] ?? n['description'] ?? ''}';
    final when = _formatWhen(n['created_at'] as String?);
    final link = (n['link_url'] as String?)?.trim() ?? '';

    showDialog<void>(
      context: context,
      barrierColor: const Color(0x800F172A),
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              if (when.isNotEmpty)
                Text(
                  when,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  msg,
                  style: const TextStyle(height: 1.45, fontSize: 15, color: AppColors.textDark),
                ),
                if (link.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => _openLink(link),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: const BorderSide(color: Color(0x59FFFFFF), width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    child: const Text('Открыть ссылку', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textDark,
                side: const BorderSide(color: Color(0x59FFFFFF), width: 2),
              ),
              child: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _merged;
    final theme = Theme.of(context);
    final cardBg = AppColors.cardDark;
    final muted = Colors.white.withValues(alpha: 0.55);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const DastrassAppDrawer(),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
        listenable: Listenable.merge([NotificationUnreadHub.instance, NotificationsLocalStore.instance]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Уведомления',
                      style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ) ??
                          const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: AppColors.textDark,
                          ),
                    ),
                  ),
                  if (items.isNotEmpty) ...[
                    _OutlineMini(label: 'Прочитано', onPressed: _markAllRead),
                    const SizedBox(width: 8),
                    _OutlineMini(label: 'Очистить', onPressed: _clearLocal),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (_loadingServer && AuthService.instance.isAuthenticated)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Пока нет уведомлений',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Когда вы добавляете/удаляете избранное, сравнение и т.д. — здесь появится история действий.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          height: 1.45,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.white.withValues(alpha: 0.08),
                        child: Text(
                          'Последние',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      for (var i = 0; i < items.length; i++) _buildRow(context, items[i], i == 0),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, Map<String, dynamic> n, bool isFirst) {
    final read = n['read'] == true;
    final title = (n['title'] as String?)?.trim().isNotEmpty == true
        ? n['title'] as String
        : 'Уведомление';
    final msg = '${n['message'] ?? n['description'] ?? ''}';
    final when = _formatWhen(n['created_at'] as String?);
    final rowBg = read ? Colors.transparent : AppColors.primary.withValues(alpha: 0.14);

    return Material(
      color: rowBg,
      child: InkWell(
        onTap: () => _onRowTap(n),
        child: Container(
          decoration: BoxDecoration(
            border: isFirst
                ? null
                : Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: read ? const Color(0xFF2F9E44) : const Color(0xFFE03131),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.25,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (msg.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        msg,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                    if (when.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        when,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineMini extends StatelessWidget {
  const _OutlineMini({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textDark,
        side: const BorderSide(color: Color(0x59FFFFFF), width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}
