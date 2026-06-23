import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.headerBar,
        foregroundColor: AppColors.textDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('О dastrass'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          'dastrass — доска объявлений: покупка, продажа и услуги рядом с вами.\n\n'
          'Мобильное приложение и сайт используют один аккаунт и общие объявления.',
          style: TextStyle(
            color: AppColors.textDark.withValues(alpha: 0.88),
            height: 1.45,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.headerBar,
        foregroundColor: AppColors.textDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Условия использования'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Условия использования сервиса dastrass.\n\n'
          'Полный текст размещён на сайте. В приложении показана краткая справка; '
          'при расхождении ориентируйтесь на актуальную версию на веб-сайте.',
          style: TextStyle(
            color: AppColors.textDark.withValues(alpha: 0.88),
            height: 1.45,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.headerBar,
        foregroundColor: AppColors.textDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Конфиденциальность'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Политика конфиденциальности dastrass.\n\n'
          'Мы обрабатываем данные, необходимые для работы объявлений и учётной записи. '
          'Подробности — на сайте в разделе «Конфиденциальность».',
          style: TextStyle(
            color: AppColors.textDark.withValues(alpha: 0.88),
            height: 1.45,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
