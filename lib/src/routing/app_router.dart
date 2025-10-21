import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../ui/csv_import_dropzone.dart';
import '../ui/desktop_scaffold.dart';

// Minimal, dependency-light router to avoid missing import errors
GoRouter buildAppRouter({required bool supabaseReady}) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    observers: [SentryNavigatorObserver()],
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'TruckerCore',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text('Application is running'),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class AppRouterRoot extends StatefulWidget {
  const AppRouterRoot({super.key});

  @override
  State<AppRouterRoot> createState() => _AppRouterRootState();
}

class _AppRouterRootState extends State<AppRouterRoot> {
  String role = 'dispatcher';

  @override
  Widget build(BuildContext context) {
    return DesktopScaffold(
      sidebar: _Sidebar(
        onNavigate: (route) => setState(() => role = route),
        active: role,
      ),
      content: switch (role) {
        'admin' => const Center(child: Text('Admin Dashboard')),
        'dispatcher' => const CsvImportDropzone(),
        'broker' => const Center(child: Text('Broker Dashboard')),
        _ => const Center(child: Text('Home')),
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final void Function(String) onNavigate;
  final String active;
  const _Sidebar({required this.onNavigate, required this.active});

  @override
  Widget build(BuildContext context) {
    final items = {
      'admin': Icons.admin_panel_settings,
      'dispatcher': Icons.local_shipping,
      'broker': Icons.account_tree,
    };
    return ListView(
      children: [
        const SizedBox(height: 12),
        for (final e in items.entries)
          ListTile(
            leading: Icon(e.value),
            title: Text(e.key[0].toUpperCase() + e.key.substring(1)),
            selected: active == e.key,
            onTap: () => onNavigate(e.key),
          ),
      ],
    );
  }
}
