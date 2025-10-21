// Router Plan Documentation
// This file documents the planned routes for the Flutter app using GoRouter.
// It is placed under docs/ to avoid affecting the current app build.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds the application router
/// 
/// Planned routes:
/// - / - Home/Dashboard
/// - /admin - Admin panel
/// - /analytics - Analytics dashboard
/// - /drivers - Driver management
/// - /fleet - Fleet management
/// - /documents - Document management
/// - /compliance - Compliance/HOS tracking
/// - /onboarding - User onboarding
GoRouter buildAppRouter({required bool supabaseReady}) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('TruckerCore')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'TruckerCore',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Application is running'),
                const SizedBox(height: 8),
                Text('Supabase Ready: $supabaseReady', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
      // TODO: Add additional routes as features are implemented
    ],
  );
}
