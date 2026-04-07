import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/dashboards/providers/dashboard_preferences_provider.dart';
import '../../features/dashboards/services/dashboard_analytics.dart';
import '../../features/dashboards/services/dashboard_layout_manager.dart';
import '../../features/dashboards/services/dashboard_shortcuts.dart';
import '../../features/dashboards/widgets/dashboard_settings_dialog.dart';

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

/// Base class for all dashboards
abstract class BaseDashboard extends ConsumerStatefulWidget {
  final DashboardConfig config;

  const BaseDashboard({super.key, required this.config});

  /// Build the dashboard UI
  Widget buildDashboard(BuildContext context, WidgetRef ref);

  /// Called when dashboard is initialized
  Future<void> onDashboardInit(WidgetRef ref) async {}

  /// Called when dashboard is disposed
  Future<void> onDashboardDispose(WidgetRef ref) async {}

  /// Called when settings are updated
  Future<void> onSettingsChanged(WidgetRef ref) async {}
}

/// Base state for dashboards with window management
abstract class BaseDashboardState<T extends BaseDashboard> extends ConsumerState<T>
    with WindowListener {
  bool _isFullscreen = false;
  Timer? _autoRefreshTimer;
  Stopwatch? _perfWatch;
  bool _perfLogged = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeWindow();
    _startAutoRefresh();
  }

  Future<void> _initializeWindow() async {
    try {
      // Ensure window manager is initialized
      await windowManager.ensureInitialized();

      // Get saved preferences
      final prefs = ref.read(dashboardPreferencesNotifierProvider(widget.config.id)).getPreferences(widget.config.id);

      // Configure window
      final config = widget.config;
      await windowManager.setTitle(config.title);

      // Use saved size/position if available
      if (prefs.savedSize != null) {
        await windowManager.setSize(prefs.savedSize!);
      } else {
        await windowManager.setSize(config.defaultSize);
      }

      if (prefs.savedPosition != null) {
        await windowManager.setPosition(prefs.savedPosition!);
      } else if (config.defaultPosition != null) {
        await windowManager.setPosition(config.defaultPosition!);
      } else {
        await windowManager.center();
      }

      await windowManager.setResizable(config.allowResize);
      await windowManager.setAlwaysOnTop(prefs.alwaysOnTop);
      await windowManager.setSkipTaskbar(!config.showInTaskbar);

      // Show window
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // In tests or non-desktop environments, window_manager may not be available.
      // Swallow errors to allow widgets to render in test environments.
    }

    // Analytics: best-effort track open
    try {
      await DashboardAnalytics.trackOpen(widget.config.id);
    } catch (_) {}

    // Initialize dashboard
    await widget.onDashboardInit(ref);
  }

  void _startAutoRefresh() {
    final prefs = ref.read(dashboardPreferencesNotifierProvider(widget.config.id)).getPreferences(widget.config.id);
    if (prefs.autoRefresh) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = Timer.periodic(Duration(seconds: prefs.refreshIntervalSeconds), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    windowManager.removeListener(this);
    widget.onDashboardDispose(ref);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Start performance watch on first build
    _perfWatch ??= Stopwatch()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_perfLogged && _perfWatch != null) {
        _perfLogged = true;
        final ms = _perfWatch!.elapsedMilliseconds;
        // Best-effort breadcrumb/log for dashboard first-frame time
        try {
          // Defer import of sentry to avoid coupling; using dynamic call via Zone is overkill.
          // Use debugPrint for now; Sentry capture occurs at app level elsewhere.
          // ignore: avoid_print
          print('[perf][dashboard:${widget.config.id}] first-frame ${ms}ms');
        } catch (_) {}
      }
    });
    return MaterialApp(
      title: widget.config.title,
      debugShowCheckedModeBanner: false,
      theme: _buildDashboardTheme(),
      home: DashboardShortcutsWidget(
        dashboardId: widget.config.id,
        onRefresh: _handleRefresh,
        onSettings: _handleSettings,
        onToggleFullscreen: _handleToggleFullscreen,
        onClose: _handleClose,
        child: Scaffold(
          body: Column(
            children: [
              _buildToolbar(context),
              Expanded(child: widget.buildDashboard(context, ref)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _handleRefresh, tooltip: 'Refresh (F5)'),
          IconButton(icon: const Icon(Icons.settings, size: 20), onPressed: _handleSettings, tooltip: 'Settings (Ctrl+,)'),
          const DashboardLayoutMenu(),
          IconButton(
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, size: 20),
            onPressed: _handleToggleFullscreen,
            tooltip: 'Fullscreen (F11)',
          ),
          IconButton(icon: const Icon(Icons.help_outline, size: 20), onPressed: _handleShowShortcuts, tooltip: 'Keyboard Shortcuts'),
          const Spacer(),
          Text(widget.config.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: _handleClose, tooltip: 'Close (Ctrl+W)'),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  ThemeData _buildDashboardTheme() {
    const baseBg = Color(0xFF12161B);
    const surface = Color(0xFF1A1F26);
    const muted = Color(0xFF2A313A);

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF58A6FF),
        secondary: Color(0xFF79C0FF),
        tertiary: Color(0xFF34D399),
        onTertiary: Colors.black,
        error: Color(0xFFFF6B6B),
        surface: surface,
        surfaceContainerHighest: muted,
        outline: muted,
        surfaceTint: Color(0xFF58A6FF),
      ),
      scaffoldBackgroundColor: baseBg,
      cardColor: surface,
      dividerColor: muted.withValues(alpha: 0.6),
    );
  }

  void _handleRefresh() {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dashboard refreshed'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _handleSettings() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DashboardSettingsDialog(dashboardId: widget.config.id, dashboardName: widget.config.title),
    );

    if (result == true && mounted) {
      // Settings changed, restart auto-refresh and apply always-on-top
      _stopAutoRefresh();
      _startAutoRefresh();
      final prefs = ref.read(dashboardPreferencesNotifierProvider(widget.config.id)).getPreferences(widget.config.id);
      try {
        await windowManager.setAlwaysOnTop(prefs.alwaysOnTop);
      } catch (_) {}
      await widget.onSettingsChanged(ref);
      setState(() {});
    }
  }

  Future<void> _handleToggleFullscreen() async {
    _isFullscreen = !_isFullscreen;
    await windowManager.setFullScreen(_isFullscreen);
    setState(() {});
  }

  void _handleClose() {
    windowManager.close();
  }

  void _handleShowShortcuts() {
    showDialog(context: context, builder: (context) => const KeyboardShortcutsHelpDialog());
  }

  @override
  void onWindowClose() async {
    // Save window position and size before closing
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await ref.read(dashboardPreferencesNotifierProvider(widget.config.id)).saveWindowPosition(widget.config.id, position, size);
    windowManager.destroy();
  }

  @override
  void onWindowFocus() {
    setState(() {});
  }

  @override
  void onWindowResize() async {
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await ref.read(dashboardPreferencesNotifierProvider(widget.config.id)).saveWindowPosition(widget.config.id, position, size);
  }

  @override
  void onWindowMove() async {
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await ref.read(dashboardPreferencesNotifierProvider(widget.config.id)).saveWindowPosition(widget.config.id, position, size);
  }
}
