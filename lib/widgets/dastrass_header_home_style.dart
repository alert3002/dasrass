import 'package:flutter/material.dart';

/// Макети header-search-row-mobile дар [frontend/src/index.css].
abstract final class DastrassHeaderHomeStyle {
  static const headerBg = Color(0xFFF7F9FF);
  static const headerBorder = Color(0x140F172A); // rgba(15, 23, 42, 0.08)

  static const searchBg = Color(0xFFE9E9E9);
  static const searchBgFocused = Color(0xFFE4E4E4);
  static const searchText = Color(0xFF1A1A1A);
  static const searchPlaceholder = Color(0x6B000000); // rgba(0, 0, 0, 0.42)
  static const iconInk = Color(0xFF111111);

  static const searchHeight = 44.0;
  static const searchRadius = 12.0;
  static const searchPadLeft = 16.0;
  static const searchPadRight = 12.0;
  static const searchInnerGap = 5.6; // 0.35rem
  static const searchBtnSize = 30.0;
  static const searchIconSize = 20.0;
  static const searchFontSize = 15.2; // 0.95rem

  static const rowGap = 10.4; // 0.65rem
  static const messagesBtnSize = 44.0;
  static const messagesIconSize = 27.2; // 1.7rem
  static const unreadDot = Color(0xFFE53935);

  static const headerPadH = 16.0; // container 1rem
  static const headerPadTop = 8.8; // 0.55rem
  static const headerPadBottom = 8.0; // 0.5rem
}
