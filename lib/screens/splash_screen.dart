import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Экрани оғоз — логотип дар марказ, фон мувофиқи тема (сафед / сиёҳ).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.progress});

  final int? progress;

  static const String _logoAsset = 'assets/images/splash_logo.png';

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final bg = light ? Colors.white : const Color(0xFF000000);
    final pct = progress?.clamp(10, 100);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  _logoAsset,
                  width: 168,
                  height: 168,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => Image.asset(
                    'assets/images/logo1.png',
                    width: 168,
                    height: 168,
                    fit: BoxFit.contain,
                  ),
                ),
                if (pct != null) ...[
                  const SizedBox(height: 36),
                  Text(
                    'Загрузка $pct%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: light ? AppColors.primary : Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 4,
                        backgroundColor: AppColors.primary.withValues(alpha: light ? 0.12 : 0.22),
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
