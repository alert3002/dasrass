import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Стили доски категории — [frontend/src/index.css] `.ads-cat-*`.
abstract final class BoardCategoryStyle {
  static const pagePadH = 16.0;
  static const headGap = 10.4; // 0.65rem
  static const headBottom = 12.0; // 0.75rem

  static const backSize = 40.0;
  static const backRadius = 12.0;
  static Color backBgLight(bool light) =>
      light ? const Color(0x14005BFE) : AppColors.primary.withValues(alpha: 0.14);

  static const titleSize = 18.4; // ~clamp min
  static const countColorLight = Color(0xFF6C757D);
  static const countWeight = FontWeight.w600;

  static const filtersPadH = 10.4; // 0.65rem
  static const filtersPadV = 8.0; // 0.5rem
  static const filtersRadius = 14.0;
  static const filtersGap = 6.4; // 0.4rem

  static Color filtersBg(bool light) =>
      light ? const Color(0xADFFFFFF) : const Color(0xE0131B2E);
  static Color filtersBorder(bool light) =>
      light ? const Color(0x29005BFE) : const Color(0x47005BFE);

  static const inputRadius = 10.0;
  static const inputHeight = 30.0;
  static const inputFontSize = 12.48; // 0.78rem
  static const inputBorderLight = Color(0xFFD8DEE8);
  static const inputBorderDark = Color(0x24FFFFFF);
  static const mutedLight = Color(0xFF6C757D);

  static const pillGap = 7.2; // 0.45rem
  static const pillPadH = 10.4; // 0.65rem
  static const pillPadV = 6.4; // 0.4rem
  static const pillFontSize = 12.8; // 0.8rem
  static const pillCountFontSize = 12.0; // 0.75rem
  static const pillBorderLight = Color(0xFFDEE2E6);
  static const pillActiveBgLight = Color(0x14005BFE);

  static const moreBorderLight = Color(0xFFDEE2E6);
  static const moreTextLight = Color(0xFF495057);
  static const moreFontSize = 12.48;
  static const morePadH = 12.0;
  static const morePadV = 5.12;

  static InputDecoration inputDecoration({
    required String hint,
    required bool light,
    double radius = inputRadius,
  }) {
    final border = light ? inputBorderLight : inputBorderDark;
    final fill = light ? Colors.white : const Color(0x0FFFFFFF);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: inputFontSize,
        color: light ? mutedLight.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.45),
        fontWeight: FontWeight.w400,
      ),
      isDense: true,
      isCollapsed: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.8, vertical: 7),
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: light ? AppColors.primary.withValues(alpha: 0.45) : inputBorderDark),
      ),
    );
  }

  static InputDecoration cityDecoration({required bool light}) {
    final border = light ? inputBorderLight : inputBorderDark;
    final fill = light ? Colors.white : const Color(0x0FFFFFFF);
    return InputDecoration(
      hintText: 'Выбрать город',
      hintStyle: TextStyle(
        fontSize: 13.5,
        color: light ? mutedLight : Colors.white.withValues(alpha: 0.55),
        fontWeight: FontWeight.w400,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: light ? AppColors.primary.withValues(alpha: 0.45) : inputBorderDark),
      ),
    );
  }
}
