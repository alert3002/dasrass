import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_bootstrap.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> _loadFontsInBackground() async {
  await GoogleFonts.pendingFonts([GoogleFonts.notoSans()]);
  enableGoogleFonts();
  ThemeController.instance.refreshAfterFontsLoaded();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(_loadFontsInBackground());
  runApp(const DastrassBootstrap());
}
