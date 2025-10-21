import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_desktop.dart' show TruckerCoreDesktopApp; // Reuse existing rich desktop app

/// Runs the desktop Flutter app using the already-configured
/// TruckerCoreDesktopApp from main_desktop.dart.
///
/// This aligns with the blueprint that expects a runDesktopApp()
/// entry which can be called from a thin platform-specific main.
void runDesktopApp() {
  runApp(const ProviderScope(child: TruckerCoreDesktopApp()));
}
