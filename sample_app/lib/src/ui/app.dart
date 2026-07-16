import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_controller.dart';
import 'home/app_shell.dart';
import 'theme.dart';

class WallifyApp extends StatelessWidget {
  const WallifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode =
        context.select<SettingsController, ThemeMode>((s) => s.themeMode);

    return MaterialApp(
      title: 'Wallify',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: wallifyTheme(Brightness.light),
      darkTheme: wallifyTheme(Brightness.dark),
      home: const AppShell(),
    );
  }
}
