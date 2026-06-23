import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/dastrass_api.dart';

/// Заголовок офлайн-баннера (главная, reels и т.д.).
const internetUnavailableTitle = 'Интернет не подключен';

/// Подзаголовок с действием «Обновить».
const internetUnavailableRefreshHint = 'Подключите интернет и нажмите «Обновить».';

/// Короткая подсказка для форм, snackbar и полей ошибки.
const internetUnavailableRetryHint = 'Подключите интернет и повторите попытку.';

bool isConnectivityError(Object error) {
  if (error is SocketException) return true;
  if (error is http.ClientException) return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('socketexception') ||
      msg.contains('clientexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('failed to fetch') ||
      msg.contains('network is unreachable') ||
      msg.contains('connection refused') ||
      msg.contains('connection timed out') ||
      msg.contains('no address associated with hostname');
}

/// Понятное сообщение для полей ошибки и snackbar.
String friendlyErrorMessage(
  Object error, {
  String fallback = 'Не удалось выполнить запрос. Попробуйте ещё раз.',
}) {
  if (isConnectivityError(error)) {
    return '$internetUnavailableTitle. $internetUnavailableRetryHint';
  }
  if (error is ApiException) {
    final m = error.message.trim();
    if (m.isNotEmpty) return m;
  }
  final raw = error.toString();
  if (raw.startsWith('Exception: ')) {
    return raw.substring('Exception: '.length);
  }
  if (raw.contains('504') || raw.contains('Gateway Timeout')) {
    return 'Сервер временно недоступен. Попробуйте позже.';
  }
  return fallback;
}

/// Многострочный текст для экранов загрузки (главная, reels).
String friendlyLoadErrorMessage(Object error) {
  if (isConnectivityError(error)) {
    return '$internetUnavailableTitle\n$internetUnavailableRefreshHint';
  }
  final raw = error.toString();
  if (raw.contains('504') || raw.contains('Gateway Timeout')) {
    return 'Сервер временно недоступен. Попробуйте позже.';
  }
  return 'Не удалось загрузить данные. Попробуйте обновить.';
}
