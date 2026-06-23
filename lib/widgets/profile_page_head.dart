import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Шапка страницы профиля — мисли `.profile-page-head` дар [Profile.jsx].
class ProfilePageHead extends StatelessWidget {
  const ProfilePageHead({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.brightness == Brightness.light ? AppColors.textLight : AppColors.textDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        'Профиль',
        style: TextStyle(
          fontSize: 17.6,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: titleColor,
        ),
      ),
    );
  }
}
