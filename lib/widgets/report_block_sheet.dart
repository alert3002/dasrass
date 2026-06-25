import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/moderation_service.dart';

const _reportReasons = [
  ('spam', 'Спам'),
  ('fraud', 'Мошенничество'),
  ('abusive', 'Оскорбления / угрозы'),
  ('illegal', 'Незаконный товар или услуга'),
  ('other', 'Другое'),
];

Future<void> showReportBlockSheet(
  BuildContext context, {
  required String adId,
  required String sellerPhone,
  VoidCallback? onBlocked,
}) async {
  if (!AuthService.instance.isAuthenticated) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в аккаунт для жалобы или блокировки')),
      );
    }
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Безопасность',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Пожаловаться на объявление или заблокировать пользователя. '
                'Заблокированный пользователь сразу исчезнет из вашей ленты. '
                'Мы рассмотрим жалобу в течение 24 часов.',
                style: TextStyle(height: 1.35),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Пожаловаться на объявление'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _reportAdFlow(context, adId: adId, sellerPhone: sellerPhone);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_flipped),
                title: const Text('Заблокировать пользователя'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _blockUserFlow(
                    context,
                    phone: sellerPhone,
                    adId: adId,
                    onBlocked: onBlocked,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _reportAdFlow(
  BuildContext context, {
  required String adId,
  required String sellerPhone,
}) async {
  String reason = _reportReasons.first.$1;
  final detailsCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Жалоба на объявление'),
      content: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: reason,
              decoration: const InputDecoration(labelText: 'Причина'),
              items: _reportReasons
                  .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                  .toList(),
              onChanged: (v) => setState(() => reason = v ?? reason),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: detailsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Комментарий (необязательно)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить')),
      ],
    ),
  );

  if (ok != true) return;
  try {
    await ModerationService.instance.reportContent(
      targetType: 'ad',
      targetId: adId,
      reason: reason,
      reportedPhone: sellerPhone,
      details: detailsCtrl.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Жалоба отправлена. Рассмотрим в течение 24 часов.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> _blockUserFlow(
  BuildContext context, {
  required String phone,
  String? adId,
  VoidCallback? onBlocked,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Заблокировать пользователя?'),
      content: const Text(
        'Все объявления и сообщения этого пользователя будут скрыты. '
        'Разработчик получит уведомление о блокировке.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Заблокировать')),
      ],
    ),
  );
  if (ok != true) return;

  try {
    await ModerationService.instance.blockUserOnServer(phone: phone, adId: adId);
    onBlocked?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь заблокирован')),
      );
      Navigator.of(context).pop();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> blockUserFromChat(
  BuildContext context, {
  required String phone,
  VoidCallback? onBlocked,
}) async {
  await _blockUserFlow(context, phone: phone, onBlocked: onBlocked);
}
