import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/dastrass_api.dart';
import '../services/message_unread_hub.dart';
import '../theme/app_theme.dart';
import '../utils/network_error_message.dart';

/// Чат по [users.views.api_messages_detail] + отправка [api_messages_send].
class MessageThreadScreen extends StatefulWidget {
  const MessageThreadScreen({
    super.key,
    required this.conversationId,
    this.titleHint,
    this.subtitleHint,
  });

  final String conversationId;
  final String? titleHint;
  final String? subtitleHint;

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final _input = TextEditingController();
  final _fmtTime = DateFormat('HH:mm');

  List<Map<String, dynamic>> _items = [];
  String? _myPhone;
  bool _loading = true;
  String? _error;
  bool _sending = false;

  int get _cid => int.tryParse(widget.conversationId) ?? 0;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await DastrassApi.instance.me();
      if (me != null && me['ok'] == true) {
        _myPhone = '${me['phone'] ?? ''}'.trim();
      }
      await _reloadMessages();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
      await MessageUnreadHub.instance.refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  Future<void> _reloadMessages() async {
    final list = await DastrassApi.instance.messageDetail(widget.conversationId);
    if (!mounted) return;
    setState(() => _items = list);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    final scroll = PrimaryScrollController.maybeOf(context);
    if (scroll == null || !scroll.hasClients) return;
    scroll.jumpTo(scroll.position.maxScrollExtent);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || _cid == 0) return;
    setState(() => _sending = true);
    try {
      await DastrassApi.instance.messageSend(conversationId: _cid, text: text);
      if (!mounted) return;
      _input.clear();
      await _reloadMessages();
      await MessageUnreadHub.instance.refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    final muted = theme.hintColor;
    final title = (widget.titleHint ?? '').trim().isNotEmpty ? widget.titleHint!.trim() : 'Переписка';
    final sub = (widget.subtitleHint ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
            if (sub.isNotEmpty)
              Text(sub, style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: onBg)),
                        ),
                      )
                    : _items.isEmpty
                        ? Center(child: Text('Нет сообщений', style: TextStyle(color: muted)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final m = _items[i];
                              final sender = '${m['sender'] ?? ''}';
                              final mine = _myPhone != null && _myPhone!.isNotEmpty && sender == _myPhone;
                              final text = '${m['text'] ?? ''}';
                              final at = m['created_at'];
                              String time = '';
                              if (at != null) {
                                final d = DateTime.tryParse('$at');
                                if (d != null) time = _fmtTime.format(d.toLocal());
                              }
                              return Align(
                                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    color: mine
                                        ? AppColors.primary.withValues(alpha: 0.22)
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (!mine)
                                            Text(
                                              sender,
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted),
                                            ),
                                          if (!mine) const SizedBox(height: 4),
                                          Text(text, style: TextStyle(color: onBg, height: 1.35)),
                                          const SizedBox(height: 4),
                                          Text(
                                            time,
                                            style: TextStyle(fontSize: 11, color: muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Material(
              elevation: 8,
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Сообщение…',
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: (_sending || !AuthService.instance.isAuthenticated) ? null : _send,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
