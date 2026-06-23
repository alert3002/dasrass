import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/dastrass_api.dart';
import '../services/message_unread_hub.dart';
import '../theme/app_theme.dart';
import '../utils/network_error_message.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static final _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    final list = await DastrassApi.instance.messageThreads();
    list.sort((a, b) {
      final ma = Map<String, dynamic>.from(a as Map);
      final mb = Map<String, dynamic>.from(b as Map);
      final da = '${ma['last_at'] ?? ''}';
      final db = '${mb['last_at'] ?? ''}';
      return db.compareTo(da);
    });
    await MessageUnreadHub.instance.refresh();
    return list;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  String _threadTitle(Map<String, dynamic> t) {
    final vt = '${t['vehicle_title'] ?? ''}'.trim();
    if (vt.isNotEmpty) return vt;
    return '${t['other_phone'] ?? 'Диалог'}';
  }

  String _lastPreview(Map<String, dynamic> t) {
    return '${t['last_text'] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    final muted = theme.hintColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщения'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(friendlyErrorMessage(snap.error!), textAlign: TextAlign.center, style: TextStyle(color: onBg)),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Найдите объявление и напишите продавцу — диалог появится здесь.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, height: 1.45, fontSize: 15),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = Map<String, dynamic>.from(list[i] as Map);
                final id = '${t['id'] ?? ''}';
                final title = _threadTitle(t);
                final sub = _lastPreview(t);
                final unread = int.tryParse('${t['unread_count'] ?? 0}') ?? 0;
                final lastAt = t['last_at'];
                String? timeLine;
                if (lastAt != null) {
                  final d = DateTime.tryParse('$lastAt');
                  if (d != null) timeLine = _dateFmt.format(d.toLocal());
                }
                final other = '${t['other_phone'] ?? ''}'.trim();

                return Material(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: id.isEmpty
                        ? null
                        : () {
                            context.push(
                              '/messages/chat/$id',
                              extra: <String, String>{
                                if (title.isNotEmpty) 'title': title,
                                if (other.isNotEmpty) 'sub': other,
                              },
                            ).then((_) => _refresh());
                          },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (unread > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 10),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                              ),
                            )
                          else
                            const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: onBg),
                                ),
                                if (other.isNotEmpty && other != title)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(other, style: TextStyle(fontSize: 12, color: muted)),
                                  ),
                                if (sub.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      sub,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: muted, height: 1.3),
                                    ),
                                  ),
                                if (timeLine != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(timeLine, style: TextStyle(fontSize: 11, color: muted.withValues(alpha: 0.85))),
                                  ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: muted.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
