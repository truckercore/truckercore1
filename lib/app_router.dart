import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'common/models/app_role.dart';
import 'common/services/user_profile_service.dart';
import 'common/state/roles_from_jwt.dart';
import 'common/state/session_provider.dart';
import 'core/ab/experiment_service.dart';
import 'core/supabase/supabase_factory.dart';
import 'di/supabase_client_provider.dart';
import 'features/admin/ab_metrics_screen.dart';
import 'features/admin/ab_panel.dart';
import 'features/admin/activity_view.dart';
import 'features/admin/api_keys_screen.dart';
import 'features/admin/operators/admin_operators_screen.dart';
import 'features/analytics/widgets/analytics_tab.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/broker/broker_dashboard.dart';
import 'features/compliance/widgets/hos_manager_tab.dart';
import 'features/compliance/widgets/inspection_dashboard.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboards/driver/driver_dashboard.dart';
import 'features/dashboards/fleet_manager/fleet_shell.dart';
import 'features/dashboards/owner_operator/owner_op_home.dart';
import 'features/dashboards/owner_operator/ownerop_shell.dart';
import 'features/dashboards/screens/dashboard_analytics_screen.dart';
import 'features/dashboards/screens/dashboard_help_screen.dart';
import 'features/dashboards/screens/dashboard_marketplace_screen.dart';
import 'features/debug/diagnostics_screen.dart';
import 'features/documents/documents_screen.dart';
import 'features/driver/screens/driver_dashboard.dart';
import 'features/driver/screens/loads_screen.dart';
import 'features/driver/screens/settings_screen.dart';
import 'features/drivers/driver_details_screen.dart';
import 'features/drivers/drivers_list_screen.dart';
import 'features/fleet/fleet_map_screen.dart';
import 'features/fleet/scorecard/driver_scorecards_screen.dart';
import 'features/fleet/trucks_admin_screen.dart';
import 'features/fleet_manager/screens/multi_fleet_dashboard.dart';
import 'features/gps/gps_map_screen.dart';
import 'features/integrations/integrations_screen.dart';
import 'features/loads/load_details_screen.dart';
import 'features/loads/loads_list_screen.dart';
import 'features/marketplace/broker_post_load_screen.dart';
import 'features/marketplace/manage_offers_screen.dart';
import 'features/marketplace/marketplace_board_screen.dart';
import 'features/owner_op/roaddogg/roaddogg_screen.dart' deferred as roaddogg_lib;
import 'features/owner_operator/screens/fleet_overview.dart';
import 'features/partner/alerts/partner_alerts_screen.dart';
import 'features/pricing/pricing_screen.dart';
import 'features/profile/driver_vehicle_settings.dart';
import 'features/profile/profile_screen.dart';
import 'features/route_planning/route_planning_screen.dart' deferred as route_plan_lib;
import 'features/shipper/shipper_dashboard.dart';
import 'features/truckstops/truck_stops_screen.dart';
import 'pages/alert_detail_page.dart';

// A small adapter that tells GoRouter to refresh when auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// A ChangeNotifier that refreshes GoRouter when a Riverpod provider changes.
class GoRouterRefreshRiverpod extends ChangeNotifier {
  GoRouterRefreshRiverpod(this._container) {
    _sub = _container.listen<UserSession>(
      sessionProvider,
      (previous, next) => notifyListeners(),
    );
  }
  final ProviderContainer _container;
  late final ProviderSubscription<UserSession> _sub;
  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Composite notifier that merges multiple notifiers into one.
class _CompositeNotifier extends ChangeNotifier {
  _CompositeNotifier(List<ChangeNotifier> notifiers) {
    for (final n in notifiers) {
      n.addListener(_onAny);
      _children.add(n);
    }
  }
  final _children = <ChangeNotifier>[];
  void _onAny() => notifyListeners();
  @override
  void dispose() {
    for (final n in _children) {
      n.removeListener(_onAny);
      n.dispose();
    }
    super.dispose();
  }
}

// Build router AFTER Supabase.initialize() has run.
// When supabaseReady == false, we avoid referencing Supabase.instance entirely.
GoRouter buildAppRouter({required bool supabaseReady}) {
  Widget guardBroker(BuildContext context, bool supReadyArg, Widget page) {
    final container = ProviderScope.containerOf(context, listen: false);
    final client = supReadyArg ? container.read(supabaseClientProvider) : null;
    final user = client?.auth.currentUser;
    if (supReadyArg && user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/auth/login');
        }
      });
      return const _SplashScreen();
    }
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final session = container.read(sessionProvider);
      if (session.role != AppRole.broker) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          switch (session.role) {
            case AppRole.driver:
              context.go('/dashboard/driver');
              break;
            case AppRole.fleetManager:
              context.go('/dashboard/dispatch');
              break;
            case AppRole.ownerOperator:
              context.go('/dashboard/owner');
              break;
            case AppRole.broker:
              // no-op
              break;
          }
        });
        return const _SplashScreen();
      }
      return page;
    } catch (_) {
      return page;
    }
  }

  // Prefer provider as single source of truth
  final containerGlobal = ProviderContainer();
  final supReady = containerGlobal.read(supabaseReadyProvider);

  // Build refresh listenable from Riverpod (session changes) and Supabase auth if available
  final notifiers = <ChangeNotifier>[];
  notifiers.add(GoRouterRefreshRiverpod(containerGlobal));
  if (supReady) {
    final client = containerGlobal.read(supabaseClientProvider);
    if (client != null) {
      final authStream = client.auth.onAuthStateChange;
      notifiers.add(GoRouterRefreshStream(authStream));
    }
  }
  final refresh = notifiers.length == 1 ? notifiers.first : _CompositeNotifier(notifiers);

  return GoRouter(
    initialLocation: '/auth/get-started',
    refreshListenable: refresh,    
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const DashboardScreen()),
      GoRoute(
        path: '/dashboard/driver',
        builder: (context, state) {
          // Guard: require auth and driver role
          final container = ProviderScope.containerOf(context, listen: false);
          final client = supReady ? container.read(supabaseClientProvider) : null;
          final user = client?.auth.currentUser;
          if (supReady && user == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/auth/login');
              }
            });
            return const _SplashScreen();
          }
          // Check role from session provider; if wrong role, send to /home
          try {
            final container = ProviderScope.containerOf(context, listen: false);
            final session = container.read(sessionProvider);
            if (session.role != AppRole.driver) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                switch (session.role) {
                  case AppRole.fleetManager:
                    context.go('/dashboard/dispatch');
                    break;
                  case AppRole.ownerOperator:
                    context.go('/dashboard/owner');
                    break;
                  case AppRole.broker:
                    context.go('/dashboard/broker');
                    break;
                  case AppRole.driver:
                    // no-op
                    break;
                }
              });
              return const _SplashScreen();
            }
          } catch (_) {
            // If we cannot read provider, allow but it's unlikely
          }
          return const DriverDashboardScreen();
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          // Safety: if someone hits root, send them to /home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            GoRouter.of(context).go('/home');
          });
          return const _SplashScreen();
        },
      ),
      GoRoute(path: '/login', builder: (context, state) {
        final redirect = state.uri.queryParameters['redirect'];
        return LoginScreen(redirectTo: redirect);
      }),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          return LoginScreen(redirectTo: redirect);
        },
      ),
      GoRoute(
        path: '/auth/get-started',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const _HomeGate(),
      ),
      GoRoute(path: '/gps', builder: (context, state) => const GpsMapScreen()),
      GoRoute(
        path: '/documents',
        builder: (context, state) => const DocumentsScreen(),
      ),
      GoRoute(
        path: '/alerts/:id',
        builder: (context, state) => AlertDetailPage(alertId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/partner/alerts',
        builder: (context, state) => const PartnerAlertsScreen(),
      ),
      GoRoute(
        path: '/truck-stops',
        builder: (context, state) => const TruckStopsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings/driver-vehicle',
        builder: (context, state) => const DriverVehicleSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/api-keys',
        builder: (context, state) => const ApiKeysScreen(),
      ),
      GoRoute(
        path: '/admin/operators',
        builder: (context, state) => const AdminOperatorsScreen(),
      ),
      GoRoute(
        path: '/admin/activity',
        builder: (context, state) => const ActivityView(),
      ),
      GoRoute(
        path: '/loads',
        builder: (context, state) => const LoadsListScreen(),
      ),
      GoRoute(
        path: '/loads/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return LoadDetailsScreen(loadId: id);
        },
      ),
      GoRoute(
        path: '/fleet-map',
        builder: (context, state) => const FleetMapScreen(),
      ),
      GoRoute(
        path: '/drivers',
        builder: (context, state) => const DriversListScreen(),
      ),
      GoRoute(
        path: '/drivers/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DriverDetailsScreen(driverUserId: id);
        },
      ),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => const PricingScreen(),
      ),
      GoRoute(
        path: '/route-planning',
        builder: (context, state) => _DeferredWidget(
          loadLibrary: route_plan_lib.loadLibrary,
          builder: (ctx) => route_plan_lib.RoutePlanningScreen(),
        ),
      ),
      GoRoute(
        path: '/trucks-admin',
        builder: (context, state) => const TrucksAdminScreen(),
      ),
      // Additional dashboards with guards
      // Fleet Manager dashboard wrapped in a ShellRoute so app bar/left nav persist
      ShellRoute(
        builder: (context, state, child) {
          final container = ProviderScope.containerOf(context, listen: false);
          final client = supReady ? container.read(supabaseClientProvider) : null;
          final user = client?.auth.currentUser;
          if (supReady && user == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/auth/login');
            });
            return const _SplashScreen();
          }
          try {
            final session = container.read(sessionProvider);
            if (session.role != AppRole.fleetManager) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                switch (session.role) {
                  case AppRole.driver:
                    context.go('/dashboard/driver');
                    break;
                  case AppRole.ownerOperator:
                    context.go('/dashboard/owner');
                    break;
                  case AppRole.broker:
                    context.go('/dashboard/broker');
                    break;
                  case AppRole.fleetManager:
                    break;
                }
              });
              return const _SplashScreen();
            }
          } catch (_) {}
          // Map child route to FleetShell's inner navigator route
          final loc = state.matchedLocation;
          String inner = '/fleet/dashboard';
          if (loc == '/dashboard/dispatch') inner = '/fleet/dispatch';
          return FleetShell(initialInnerRoute: inner);
        },
        routes: [
          GoRoute(
            path: '/dashboard/dispatch',
            // Child content is provided by FleetShell's inner Navigator; use a stub
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
      // Owner-Operator shell with nested Navigator
      GoRoute(
        path: '/dashboard/owner',
        builder: (context, state) {
          final container = ProviderScope.containerOf(context, listen: false);
          final client = supReady ? container.read(supabaseClientProvider) : null;
          final user = client?.auth.currentUser;
          if (supReady && user == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/auth/login');
            });
            return const _SplashScreen();
          }
          try {
            final container = ProviderScope.containerOf(context, listen: false);
            final session = container.read(sessionProvider);
            if (session.role != AppRole.ownerOperator) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                switch (session.role) {
                  case AppRole.driver:
                    context.go('/dashboard/driver');
                    break;
                  case AppRole.fleetManager:
                    context.go('/dashboard/dispatch');
                    break;
                  case AppRole.broker:
                    context.go('/dashboard/broker');
                    break;
                  case AppRole.ownerOperator:
                    // no-op
                    break;
                }
              });
              return const _SplashScreen();
            }
            return const OwnerOpShell();
          } catch (_) {
            return const OwnerOpHome(isPremium: false);
          }
        },
      ),
      GoRoute(
        path: '/roaddogg',
        builder: (context, state) {
          final container = ProviderScope.containerOf(context, listen: false);
          final client = supReady ? container.read(supabaseClientProvider) : null;
          final user = client?.auth.currentUser;
          if (supReady && user == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/auth/login');
            });
            return const _SplashScreen();
          }
          try {
            final container = ProviderScope.containerOf(context, listen: false);
            final session = container.read(sessionProvider);
            if (session.role != AppRole.ownerOperator) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                switch (session.role) {
                  case AppRole.driver:
                    context.go('/dashboard/driver');
                    break;
                  case AppRole.fleetManager:
                    context.go('/dashboard/dispatch');
                    break;
                  case AppRole.broker:
                    context.go('/dashboard/broker');
                    break;
                  case AppRole.ownerOperator:
                    // no-op
                    break;
                }
              });
              return const _SplashScreen();
            }
            return _DeferredWidget(
              loadLibrary: roaddogg_lib.loadLibrary,
              builder: (ctx) => roaddogg_lib.RoadDoggScreen(),
            );
          } catch (_) {
            return _DeferredWidget(
              loadLibrary: roaddogg_lib.loadLibrary,
              builder: (ctx) => roaddogg_lib.RoadDoggScreen(),
            );
          }
        },
      ),
      GoRoute(
        path: '/dashboard/broker',
        builder: (context, state) =>
            guardBroker(context, supabaseReady, const BrokerDashboardScreen()),
      ),
      GoRoute(
        path: '/broker/loads',
        builder: (context, state) => guardBroker(
          context,
          supabaseReady,
          const BrokerSectionScreen(title: 'All Loads'),
        ),
      ),
      GoRoute(
        path: '/broker/carriers',
        builder: (context, state) => guardBroker(
          context,
          supabaseReady,
          const BrokerSectionScreen(title: 'Carriers & Drivers'),
        ),
      ),
      GoRoute(
        path: '/broker/matches',
        builder: (context, state) => guardBroker(
          context,
          supabaseReady,
          const BrokerSectionScreen(title: 'Matches & Outreach'),
        ),
      ),
      GoRoute(
        path: '/broker/contracts',
        builder: (context, state) => guardBroker(
          context,
          supabaseReady,
          const BrokerSectionScreen(title: 'Contracts & Docs'),
        ),
      ),
      GoRoute(
        path: '/broker/billing',
        builder: (context, state) => guardBroker(
          context,
          supabaseReady,
          const BrokerSectionScreen(title: 'Billing & Invoices'),
        ),
      ),
      GoRoute(
        path: '/broker/analytics',
        builder: (context, state) => guardBroker(
          context,
          supabaseReady,
          const BrokerSectionScreen(title: 'Analytics'),
        ),
      ),
      GoRoute(
        path: '/broker/messages',
        builder: (context, state) => guardBroker(
          context,
          supabaseReady,
          const BrokerSectionScreen(title: 'Messages'),
        ),
      ),
      GoRoute(
        path: '/dashboard/shipper',
        builder: (context, state) => const ShipperDashboardScreen(),
      ),
      // Deep linkable inner routes for Fleet shell
      GoRoute(path: '/fleet/dashboard', builder: (context, state) => const FleetShell()),
      GoRoute(path: '/fleet/dispatch', builder: (context, state) => const FleetShell(initialInnerRoute: '/fleet/dispatch')),
      GoRoute(path: '/fleet/safety', builder: (context, state) => const FleetShell(initialInnerRoute: '/fleet/safety')),
      GoRoute(path: '/fleet/analytics', builder: (context, state) => const FleetShell(initialInnerRoute: '/fleet/analytics')),
      GoRoute(path: '/fleet/settings', builder: (context, state) => const FleetShell(initialInnerRoute: '/fleet/settings')),
      // Deep linkable inner routes for Owner-Op shell
      GoRoute(path: '/ownerop/home', builder: (context, state) => const OwnerOpShell()),
      GoRoute(path: '/ownerop/loads', builder: (context, state) => const OwnerOpShell(initialInnerRoute: '/ownerop/loads')),
      GoRoute(path: '/ownerop/expenses', builder: (context, state) => const OwnerOpShell(initialInnerRoute: '/ownerop/expenses')),
      GoRoute(path: '/ownerop/documents', builder: (context, state) => const OwnerOpShell(initialInnerRoute: '/ownerop/documents')),
      GoRoute(path: '/ownerop/settings', builder: (context, state) => const OwnerOpShell(initialInnerRoute: '/ownerop/settings')),
      GoRoute(
        path: '/broker/marketplace',
        builder: (context, state) =>
            guardBroker(context, supabaseReady, const MarketplaceBoardScreen()),
      ),
      GoRoute(
        path: '/broker/post-load',
        builder: (context, state) =>
            guardBroker(context, supabaseReady, const BrokerPostLoadScreen()),
      ),
      GoRoute(
        path: '/fleet/manage-offers',
        builder: (context, state) => const ManageOffersScreen(),
      ),
      GoRoute(
        path: '/broker/settings',
        builder: (context, state) => guardBroker(
          context,
          supabaseReady,
          const BrokerSectionScreen(title: 'Settings'),
        ),
      ),
      // Analytics (Fleet/Broker)
      GoRoute(
        path: '/analytics',
        builder: (ctx, state) => const _AnalyticsScreen(),
      ),
      GoRoute(
        path: '/debug/diagnostics',
        builder: (ctx, state) => const DiagnosticsScreen(),
      ),
      // AB metrics admin
      GoRoute(
        path: '/admin/ab-metrics',
        builder: (ctx, state) => const AbMetricsScreen(),
      ),
      GoRoute(
        path: '/admin/ab-panel',
        builder: (ctx, state) => Scaffold(appBar: AppBar(title: const Text('Experiment Admin')), body: const SafeArea(child: SingleChildScrollView(padding: EdgeInsets.all(12), child: AdminAbPanel()))),
      ),
      GoRoute(
        path: '/ops/integrations',
        builder: (ctx, state) => const IntegrationsScreen(),
      ),
      GoRoute(
        path: '/marketplace',
        builder: (context, state) => const MarketplaceBoardScreen(),
      ),
      GoRoute(
        path: '/dashboards',
        builder: (context, state) => const DashboardMarketplaceScreen(),
      ),
      GoRoute(
        path: '/dashboards/help',
        builder: (context, state) => const DashboardHelpScreen(),
      ),
      GoRoute(
        path: '/dashboards/analytics',
        builder: (context, state) => const DashboardAnalyticsScreen(),
      ),
      // HOS Manager view
      GoRoute(
        path: '/compliance/hos',
        builder: (ctx, state) => const _HosManagerScreen(),
      ),
      // Fleet driver scorecards
      GoRoute(
        path: '/fleet/scorecards',
        builder: (ctx, state) => const _DriverScorecardsRouteShim(),
      ),
      // Inspection dashboard
      GoRoute(
        path: '/compliance/inspections',
        builder: (ctx, state) => const InspectionDashboardScreen(),
      ),
      // --- Driver routes (new) ---
      GoRoute(
        path: '/driver',
        redirect: (_, __) => '/driver/dashboard',
      ),
      GoRoute(
        path: '/driver/dashboard',
        builder: (context, state) => const DriverDashboard(),
      ),
      GoRoute(
        path: '/driver/loads',
        builder: (context, state) => const LoadsScreen(),
      ),
      GoRoute(
        path: '/driver/hos',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('HOS Screen - TODO')),
        ),
      ),
      GoRoute(
        path: '/driver/documents',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Documents Screen - TODO')),
        ),
      ),
      GoRoute(
        path: '/driver/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      // --- Owner Operator routes (new) ---
      GoRoute(
        path: '/owner-operator',
        redirect: (_, __) => '/owner-operator/dashboard',
      ),
      GoRoute(
        path: '/owner-operator/dashboard',
        builder: (context, state) => const FleetOverviewScreen(),
      ),
      GoRoute(
        path: '/owner-operator/vehicles',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Vehicles Screen - TODO')),
        ),
      ),
      GoRoute(
        path: '/owner-operator/drivers',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Drivers Screen - TODO')),
        ),
      ),
      GoRoute(
        path: '/owner-operator/loads',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Loads Screen - TODO')),
        ),
      ),
      GoRoute(
        path: '/owner-operator/reports',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Reports Screen - TODO')),
        ),
      ),
      // --- Fleet Manager routes (new) ---
      GoRoute(
        path: '/fleet-manager',
        redirect: (_, __) => '/fleet-manager/dashboard',
      ),
      GoRoute(
        path: '/fleet-manager/dashboard',
        builder: (context, state) => const MultiFleetDashboard(),
      ),
      GoRoute(
        path: '/fleet-manager/fleets',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Fleets Screen - TODO')),
        ),
      ),
      GoRoute(
        path: '/fleet-manager/users',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Users Screen - TODO')),
        ),
      ),
      GoRoute(
        path: '/fleet-manager/compliance',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Compliance Screen - TODO')),
        ),
      ),
      GoRoute(
        path: '/fleet-manager/analytics',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Analytics Screen - TODO')),
        ),
      ),
      GoRoute(
        path: '/fleet-manager/audit-logs',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Audit Logs Screen - TODO')),
        ),
      ),
    ],
    redirect: (context, state) {
      // If Supabase isn't ready, send user to offline page except when already there
      if (!supReady) {
        if (state.matchedLocation != '/offline') {
          return '/offline';
        }
        return null;
      }
      final container = ProviderScope.containerOf(context, listen: false);
      final client = container.read(supabaseClientProvider);
      final supaUser = client?.auth.currentUser;
      final isLoggedIn = supaUser != null;
      final loggingIn =
          state.fullPath == '/login' ||
          state.fullPath == '/auth/login' ||
          state.fullPath == '/auth/get-started' ||
          state.matchedLocation == '/offline';
      // Public routes
      final isPublicRoute = state.matchedLocation.startsWith('/auth') || state.matchedLocation == '/offline';
      if (!isLoggedIn && !isPublicRoute) {
        // ignore: avoid_print
        print('[router] redirect → /auth/get-started (isLoggedIn=$isLoggedIn path=${state.fullPath})');
        return '/auth/get-started';
      }
      if (isLoggedIn && (state.fullPath == '/' || loggingIn)) {
        // Defer role-based landing to the HomeGate
        // ignore: avoid_print
        print('[router] redirect → /home (isLoggedIn=$isLoggedIn path=${state.fullPath})');
        return '/home';
      }
      // Premium gating for certain routes
      final isPremium = container.read(sessionProvider).isPremium;
      final loc = state.matchedLocation;
      if ((loc.startsWith('/roaddogg') || loc.startsWith('/route-planning')) && !isPremium) {
        return '/pricing';
      }
      return null;
    },
    observers: [
      SentryNavigatorObserver(),
      _AnalyticsRouterObserver(),
    ],
  );
}

// Choose the correct home screen based on the current user's role
Widget roleHome(UserSession session) {
  switch (session.role) {
    case AppRole.driver:
      return const DriverDashboardScreen();
    case AppRole.fleetManager:
      return const FleetShell();
    case AppRole.ownerOperator:
      return const OwnerOpShell();
    case AppRole.broker:
      return const BrokerDashboardScreen();
  }
}

class _HomeGate extends ConsumerStatefulWidget {
  const _HomeGate();
  @override
  ConsumerState<_HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends ConsumerState<_HomeGate> { 
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Ensure role restoration completes before deciding where to go
      try {
        await ref.read(sessionProvider.notifier).waitUntilRestored();
      } catch (_) {}
      if (!mounted) return; // Guard after async gap
      final supReady = ref.read(supabaseReadyProvider);
      if (supReady) {
        // Try to fetch profile and sync session when authenticated
        final client = ref.read(supabaseClientProvider);
        final user = client?.auth.currentUser;
        if (user != null) {
          final svc = ref.read(userProfileServiceProvider);
          final profile = await svc.fetchMyProfile();
          if (!mounted) return; // Guard after async gap
          if (profile != null) {
            ref
                .read(sessionProvider.notifier)
                .setFromProfile(profile.role, profile.isPremium);
            // Debug: log profile-based role resolution
            // ignore: avoid_print
            print(
              '[home_gate] profile role=${profile.role} premium=${profile.isPremium} user=${user.email ?? user.id}',
            );
          }
          // A/B: ensure ranker_v1 assignment for this user
          try {
            await ref.read(experimentControllerProvider.notifier).ensureAssigned('ranker_v1', user.id);
          } catch (_) {}
          // If JWT has combo roles, honor primary and allow quick selection
          final jwt = ref.read(jwtRolesProvider);
          final sessionCtrl = ref.read(sessionProvider.notifier);
          if (jwt.roles.isNotEmpty) {
            // Decide priority: profile role wins unless user explicitly chose.
            final session = ref.read(sessionProvider);
            final alreadyChosen = session.userChosenRole;
            final profileAppliedRole = session.role; // use current session as source of truth
            // Only consider applying JWT.primary if:
            // - user has NOT explicitly chosen a role, AND
            // - we do NOT have a profile-applied role that differs (i.e., skip override), AND
            // - jwt.primary is present and differs from current role
            if (!alreadyChosen && jwt.primary != null && jwt.primary != profileAppliedRole) {
              // We will not override a profile-applied role silently. Log and skip.
              // ignore: avoid_print
              print('[home_gate] jwt.primary=${jwt.primary} differs from profile/session=$profileAppliedRole → skip override');
            } else if (!alreadyChosen && jwt.primary != null && jwt.primary == profileAppliedRole) {
              // They match; no need to set, but log for clarity.
              // ignore: avoid_print
              print('[home_gate] jwt.primary matches session (${jwt.primary}); no change');
            }
            // If multiple roles and no explicit persisted choice, offer a quick picker once
            if (jwt.roles.length > 1) {
              await Future<void>.delayed(Duration.zero); // ensure context ready
              if (mounted) {
                // Non-blocking sheet to choose default mode
                // Skip if we already have a non-primary role selected (user switched earlier)
                final cur = ref.read(sessionProvider).role;
                final alreadyChosen = cur != (jwt.primary ?? cur);
                if (!alreadyChosen) {
                  // best-effort prompt; can be replaced by a full Role Selector page later
                  // ignore use_build_context_synchronously warning in analyzer context — guarded by mounted
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (ctx) {
                      return SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Choose your default mode',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final r in jwt.roles)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        sessionCtrl.setRole(r, userChosen: true);
                                        Navigator.pop(ctx);
                                      },
                                      icon: const Icon(Icons.swap_horiz),
                                      label: Text(
                                        r == AppRole.fleetManager
                                            ? 'Carrier'
                                            : r == AppRole.ownerOperator
                                                ? 'Owner Operator'
                                                : r.name,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'You can switch anytime from the top bar.',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              }
            }
          }
        }
      }
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const _SplashScreen();
    }
    if (_error != null) {
      // On error, still proceed with whatever session we have to avoid blocking
      debugPrint('HomeGate error: $_error');
    }
    final session = ref.watch(sessionProvider);
    // Debug: log final role-based navigation decision
    // ignore: avoid_print
    print(
      '[home_gate] navigating to role=${session.role} premium=${session.isPremium}',
    );
    return roleHome(session);
  }
}

// Simple splash screen shown while redirect logic decides where to go
class _AnalyticsScreen extends StatelessWidget {
  const _AnalyticsScreen();
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Fleet'),
              Tab(text: 'Broker'),
            ],
          ),
        ),
        body: const TabBarView(children: [AnalyticsTab(), AnalyticsTab()]),
      ),
    );
  }
}

class _HosManagerScreen extends StatelessWidget {
  const _HosManagerScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HOS Compliance')),
      body: const SafeArea(child: HosManagerTab()),
    );
  }
}

class _DriverScorecardsRouteShim extends StatelessWidget {
  const _DriverScorecardsRouteShim();
  @override
  Widget build(BuildContext context) {
    return const DriverScorecardsScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}


/// Custom router observer that logs navigation events to Sentry breadcrumbs
class _AnalyticsRouterObserver extends NavigatorObserver {
  void _breadcrumb(String message, Route<dynamic>? route) {
    final settings = route?.settings;
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: 'navigation',
      level: SentryLevel.info,
      data: {
        'name': settings?.name,
        'arguments': settings?.arguments?.toString(),
      },
    ));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _breadcrumb('push', route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _breadcrumb('pop', previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _breadcrumb('replace', newRoute);
  }
}

/// A helper widget that defers loading of a library before building a child
class _DeferredWidget extends StatefulWidget {
  const _DeferredWidget({required this.loadLibrary, required this.builder});
  final Future<void> Function() loadLibrary;
  final Widget Function(BuildContext) builder;

  @override
  State<_DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<_DeferredWidget> {
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await widget.loadLibrary();
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      _error = e;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Failed to load: $_error')),
      );
    }
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.builder(context);
  }
}
