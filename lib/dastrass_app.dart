import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class DastrassApp extends StatelessWidget {
  const DastrassApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Dasrass',
          debugShowCheckedModeBanner: false,
          theme: appLightTheme,
          darkTheme: appDarkTheme,
          themeMode: ThemeController.instance.mode,
          routerConfig: router,
        );
      },
    );
  }
}
