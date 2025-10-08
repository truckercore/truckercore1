import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class DashboardConfig {
  final String id;
  final String title;
  final Size defaultSize;
  final Offset? defaultPosition;
  final bool allowResize;
  final bool alwaysOnTop;
  final bool showInTaskbar;

  const DashboardConfig({
    required this.id,
    required this.title,
    this.defaultSize = const Size(1200, 800),
    this.defaultPosition,
    this.allowResize = true,
    this.alwaysOnTop = false,
    this.showInTaskbar = true,
  });
}

abstract class BaseDashboard extends ConsumerStatefulWidget {
  final DashboardConfig config;

  const BaseDashboard({super.key, required this.config});

  Widget buildDashboard(BuildContext context, WidgetRef ref);

  Future<void> onDashboardInit(WidgetRef ref) async {}

  Future<void> onDashboardDispose(WidgetRef ref) async {}
}

abstract class BaseDashboardState<T extends BaseDashboard> extends ConsumerState<T>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeWindow();
  }

  Future<void> _initializeWindow() async {
    try {
      await windowManager.ensureInitialized();
      await windowManager.setTitle(widget.config.title);
      await windowManager.setSize(widget.config.defaultSize);
      if (widget.config.defaultPosition != null) {
        await windowManager.setPosition(widget.config.defaultPosition!);
      } else {
        await windowManager.center();
      }
      await windowManager.setResizable(widget.config.allowResize);
      await windowManager.setAlwaysOnTop(widget.config.alwaysOnTop);
      await windowManager.setSkipTaskbar(!widget.config.showInTaskbar);
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
    await widget.onDashboardInit(ref);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.onDashboardDispose(ref);
    super.dispose();
  }

  ThemeData _buildDashboardTheme() {
    const baseBg = Color(0xFF12161B);
    const surface = Color(0xFF1A1F26);
    const muted = Color(0xFF2A313A);

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: Color(0xFF58A6FF),
        onPrimary: Colors.black,
        secondary: Color(0xFF79C0FF),
        onSecondary: Colors.black,
        tertiary: Color(0xFF34D399),
        onTertiary: Colors.black,
        error: Color(0xFFFF6B6B),
        onError: Colors.black,
        surface: surface,
        onSurface: Colors.white,
        surfaceContainerHighest: muted,
        outline: muted,
        surfaceTint: Color(0xFF58A6FF),
      ),
      scaffoldBackgroundColor: baseBg,
      cardColor: surface,
      dividerColor: muted.withOpacity(0.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _buildDashboardTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Builder(builder: (context) => widget.buildDashboard(context, ref)),
        ),
      ),
    );
  }

  @override
  void onWindowClose() {
    windowManager.destroy();
  }

  @override
  void onWindowFocus() {
    setState(() {});
  }
}
