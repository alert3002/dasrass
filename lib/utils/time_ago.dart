import 'package:intl/intl.dart';

DateTime _oneCalendarMonthAgo() {
  final now = DateTime.now();
  var month = now.month - 1;
  var year = now.year;
  if (month < 1) {
    month += 12;
    year -= 1;
  }
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = now.day > lastDay ? lastDay : now.day;
  return DateTime(year, month, day, now.hour, now.minute, now.second);
}

/// «2 ч назад» → «3 дн назад» → баъд аз 1 моҳ: «01.12.2026».
String formatTimeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';

  final created = parsed.isUtc ? parsed.toLocal() : parsed;
  if (created.isBefore(_oneCalendarMonthAgo())) {
    return DateFormat('dd.MM.yyyy').format(created);
  }

  final diff = DateTime.now().difference(created);
  if (diff.isNegative) return 'только что';

  if (diff.inMinutes < 1) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} минут назад';
  if (diff.inHours < 24) return '${diff.inHours} ч назад';
  return '${diff.inDays} дн назад';
}
