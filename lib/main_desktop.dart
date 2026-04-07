import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/bootstrap/supabase_bootstrap.dart';
import 'src/desktop/system_tray.dart';
import 'src/desktop/window_shell.dart';
import 'src/routing/app_router.dart';

Future<void> registerHotkeys() async {
  // Hotkeys temporarily disabled to maintain analyzer compatibility across platforms.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bootstrap services (Supabase, secure storage, DB, etc.)
  await bootstrapSupabase();

  // System tray setup
  if (!Platform.isAndroid && !Platform.isIOS) {
    await SystemTrayService.ensureInitialized();
  }

  // Register example global hotkeys (disabled for now)
  // await registerHotkeys();

  runApp(const ProviderScope(child: TruckerCoreDesktopApp()));

  // Bitsdojo window frame behavior
  doWhenWindowReady(() {
    const initialSize = Size(1200, 800);
    appWindow.minSize = const Size(1000, 700);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = 'TruckerCore Desktop';
    appWindow.show();
  });
}

class TruckerCoreDesktopApp extends StatelessWidget {
  const TruckerCoreDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckerCore Desktop',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0E7490),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF0E7490),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DesktopWindowShell(
        child: AppRouterRoot(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
