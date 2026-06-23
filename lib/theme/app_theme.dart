import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Бренд как на сайте: #005BFE, тёмный фон #0b1220.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF005BFE);
  static const Color primaryHover = Color(0xFF0040C4);
  /// Как мобильный header на React (расми 1)
  static const Color headerBar = Color(0xFF0A0B10);
  /// Сатри мобил дар темаи равшан (мисли таб-бар).
  static const Color headerBarLight = Color(0xF7FFFFFF);
  /// Фон шапки главной (мисли site-header--home).
  static const Color headerHomeLight = Color(0xFFF7F9FF);
  static const Color bgDark = Color(0xFF0B1220);
  static const Color cardDark = Color(0xFF131B2E);
  static const Color textDark = Color(0xFFE8ECF4);
  static const Color mutedDark = Color(0x8AFFFFFF);

  static const Color bgLight = Color(0xFFF6F8FF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF1A1F36);

  /// Фон области фото в карточке объявления (светлая / тёмная тема).
  static const Color adGalleryPhotoBgLight = Color(0xFFE9E9EB);
  static const Color adGalleryPhotoBgDark = Color(0xFF000000);
}

Color adGalleryPhotoBg(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.adGalleryPhotoBgDark
      : AppColors.adGalleryPhotoBgLight;
}

bool _googleFontsReady = false;

/// Noto Sans — Latin + Cyrillic + ҳарфҳои тоҷикӣ (Қ, Ғ, Ҳ, …).
/// Дар аввалин frame системный шрифт — Noto дар фон бор мешавад.
void enableGoogleFonts() {
  if (_googleFontsReady) return;
  _googleFontsReady = true;
  _cachedLight = null;
  _cachedDark = null;
}

TextTheme _appTextTheme(TextTheme base, {required Color body, required Color display}) {
  final themed = _googleFontsReady
      ? GoogleFonts.notoSansTextTheme(base)
      : base;
  return themed.apply(
    bodyColor: body,
    displayColor: display,
  );
}

ThemeData _applyAppTheme(ThemeData base, TextTheme textTheme) {
  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: base.brightness == Brightness.dark
          ? const Color(0x14FFFFFF)
          : const Color(0xFFF0F2FA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: base.brightness == Brightness.dark
              ? const Color(0x24FFFFFF)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: base.colorScheme.onSurface,
        side: BorderSide(
          color: base.brightness == Brightness.dark
              ? const Color(0x59FFFFFF)
              : Colors.black.withValues(alpha: 0.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.cardDark,
      onSurface: AppColors.textDark,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.headerBar,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x1AFFFFFF)),
      ),
    ),
  );
  final textTheme = _appTextTheme(
    base.textTheme,
    body: AppColors.textDark,
    display: AppColors.textDark,
  );
  return _applyAppTheme(base, textTheme);
}

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      surface: AppColors.cardLight,
      onSurface: AppColors.textLight,
    ),
    scaffoldBackgroundColor: AppColors.bgLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
    ),
  );
  final textTheme = _appTextTheme(
    base.textTheme,
    body: AppColors.textLight,
    display: AppColors.textLight,
  );
  return _applyAppTheme(base, textTheme);
}

ThemeData? _cachedLight;
ThemeData? _cachedDark;

/// Кэш — барои аввалин frame зудтар.
ThemeData get appLightTheme => _cachedLight ??= buildLightTheme();
ThemeData get appDarkTheme => _cachedDark ??= buildDarkTheme();
