import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' as go;
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:truckercore1/services/supa_client.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'core/dashboards/dashboard_entry.dart';

import 'app_router.dart';
import 'common/config/app_config.dart';
import 'common/config/app_env.dart';
import 'common/widgets/app_background.dart';
import 'common/widgets/offline_banner.dart';
import 'core/flags/rollout_flags.dart';
import 'core/observability/log_buffer.dart';
import 'core/refresh/refresh_orchestrator.dart';
import 'core/supabase/supabase_factory.dart';
import 'core/ui/pilot_banner.dart';
import 'core/ui/status_banner.dart';
import 'features/connectivity/connectivity_provider.dart';
import 'features/fleet/data/basic_fleet_repository.dart';
import 'features/fleet/data/fleet_repository.dart';
import 'features/fleet/data/mock_fleet_repository.dart';

final log = Logger(
  filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
  printer: PrettyPrinter(methodCount: 0),
  output: MultiOutput([
    ConsoleOutput(),
    MemoryLogOutput(LogBuffer.instance),
  ]),
);

Future<void> main([List<String>? args]) async {
  // Handle dashboard sub-window launched by desktop_multi_window
  final a = args ?? const <String>[];
  if (a.isNotEmpty && a.first == 'multi_window') {
    final windowId = int.parse(a[1]);
    final controller = WindowController.fromWindowId(windowId);

    WidgetsFlutterBinding.ensureInitialized();
    await _initializeSupabaseForDashboard();

    runApp(DashboardEntry(controller: controller));
    return;
  }
  // Ensure the Flutter bindings are initialized in the correct zone first
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge system UI on Android/iOS
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Load environment variables from .env (optional; ignore if not bundled)
  // On web, this asset may not exist; avoid throwing if it does not.
  try {
    if (!kIsWeb) {
      await dotenv.load();
    } else {
      // For web, rely on --dart-define or public runtime config; .env is typically not served.
    }
  } catch (_) {/* no .env asset or not needed */}

  // Emit one-time warning if using legacy env var name
  AppEnv.maybeWarnLegacy();

    // Build runtime AppConfig using dart-define first, then .env (if present), then fallback to existing appConfigFromEnv
    final ddUrl = AppEnv.supabaseUrl;
    final ddAnon = AppEnv.supabaseAnonKey; // prefers SUPABASE_ANON, falls back to SUPABASE_ANON_KEY

    String envOrEmpty(String key) {
      try {
        // maybeGet returns null when dotenv isn't initialized or key missing
        final v = dotenv.maybeGet(key);
        return v ?? '';
      } catch (_) {
        return '';
      }
    }

    final envUrl = envOrEmpty('SUPABASE_URL');
    // Prefer standardized SUPABASE_ANON; fall back to legacy SUPABASE_ANON_KEY
    final envAnonNew = envOrEmpty('SUPABASE_ANON');
    final envAnonLegacy = envOrEmpty('SUPABASE_ANON_KEY');
    final supabaseUrlEnv = ddUrl.isNotEmpty
        ? ddUrl
        : (envUrl.isNotEmpty ? envUrl : appConfigFromEnv.supabaseUrl);
    final supabaseAnonEnv = ddAnon.isNotEmpty
        ? ddAnon
        : (envAnonNew.isNotEmpty ? envAnonNew : envAnonLegacy.isNotEmpty ? envAnonLegacy : appConfigFromEnv.supabaseAnonKey);

    final cfg = AppConfig(
      backend: appConfigFromEnv.backend,
      mapboxToken: appConfigFromEnv.mapboxToken,
      trimbleBaseUrl: appConfigFromEnv.trimbleBaseUrl,
      useMockData: appConfigFromEnv.useMockData,
      supabaseUrl: supabaseUrlEnv,
      supabaseAnonKey: supabaseAnonEnv,
      idleMinutes: appConfigFromEnv.idleMinutes,
      offlineMinutes: appConfigFromEnv.offlineMinutes,
      speedIdleKph: appConfigFromEnv.speedIdleKph,
    );
  // Validate public env in non-mock mode (fail fast in debug)
  if (!appConfigFromEnv.useMockData) {
    AppEnv.validateOrThrow();
  }
  var initializedSupabase = false;
  // Respect mock mode: when useMockData is true, skip Supabase initialization entirely
  if (!cfg.useMockData &&
      cfg.supabaseUrl.isNotEmpty &&
      cfg.supabaseAnonKey.isNotEmpty) {
    log.i('[startup] Supabase.initialize → url=${cfg.supabaseUrl}');
    await Supabase.initialize(
      url: cfg.supabaseUrl,
      anonKey: cfg.supabaseAnonKey,
    );
    // Configure default org/role headers for custom HTTP client usages
    try {
      // Lazy read on each request to keep current session values
      SupaClient.defaultExtraHeaders = () {
        final headers = <String, String>{};
        try {
          final user = Supabase.instance.client.auth.currentUser;
          final session = Supabase.instance.client.auth.currentSession;
          // org_id: prefer user metadata claim, fallback to custom claim in JWT
          final orgFromMeta = user?.userMetadata?['org_id']?.toString();
          String? orgId = orgFromMeta;
          try {
            if (orgId == null) {
              final token = session?.accessToken;
              if (token is String && token.split('.').length == 3) {
                final payload = token.split('.')[1];
                final norm = base64.normalize(payload);
                final decoded = utf8.decode(base64.decode(norm));
                final claims = jsonDecode(decoded) as Map<String, dynamic>;
                final cOrg = claims['app_org_id']?.toString();
                if (cOrg != null && cOrg.isNotEmpty) orgId = cOrg;
                // roles from claims if present
                final dynRoles = claims['app_roles'];
                if (dynRoles is List && dynRoles.isNotEmpty) {
                  final rs = dynRoles.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
                  if (rs.isNotEmpty) headers['x-app-roles'] = rs.join(',');
                }
                final primary = claims['app_primary_role']?.toString();
                if (primary != null && primary.isNotEmpty) {
                  // ensure primary included first
                  final existing = headers['x-app-roles'];
                  if (existing == null || !existing.split(',').contains(primary)) {
                    headers['x-app-roles'] = existing == null ? primary : '$primary,$existing';
                  }
                }
              }
            }
          } catch (_) {}
          if (orgId != null && orgId.isNotEmpty) headers['x-app-org-id'] = orgId;
          // If roles were not extracted, try minimal fallback based on last known primary role in user metadata
          if (!headers.containsKey('x-app-roles')) {
            final r = user?.userMetadata?['primary_role']?.toString();
            if (r != null && r.isNotEmpty) headers['x-app-roles'] = r;
          }
        } catch (_) {}
        return headers;
      };
    } catch (_) {}
    initializedSupabase = true;
    log.i('[startup] Supabase initialized OK');
  } else {
    final reason = cfg.useMockData
        ? 'useMockData=true'
        : 'missing SUPABASE_URL or SUPABASE_ANON';
    log.w('[startup] No Supabase initialization. Reason=$reason');
  }

  // Performance stopwatch for cold start until first frame
  final startupWatch = Stopwatch()..start();

  // Defer non-critical work and record first-frame timing
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final ms = startupWatch.elapsedMilliseconds;
    log.i('[perf] first-frame ${ms}ms');
    try {
      await Sentry.addBreadcrumb(Breadcrumb(
        message: 'first-frame',
        data: {'elapsed_ms': ms},
        category: 'perf',
        level: SentryLevel.info,
      ));
      // Desktop environment snapshot (HiDPI/locale)
      final pd = WidgetsBinding.instance.platformDispatcher;

      final dpr = pd.views.isNotEmpty ? pd.views.first.devicePixelRatio : 1.0;
      final locales = pd.locales.map((l) => l.toLanguageTag()).toList(growable: false);
      String decimalSep = '.';
      try {
        // Simple check for decimal separator using intl
        final sample = 1.1.toStringAsFixed(1);
        decimalSep = sample.contains(',') ? ',' : '.';
      } catch (_) {}
      await Sentry.addBreadcrumb(Breadcrumb(
        message: 'desktop-environment',
        category: 'env',
        data: {
          'device_pixel_ratio': dpr,
          'locales': locales,
          'decimal_sep_guess': decimalSep,
        },
        level: SentryLevel.info,
      ));
    } catch (_) {}
    // CI smoke check: if environment variable is set, exit after first frame
    try {
      final smoke = Platform.environment['SMOKE_TEST'];
      if (smoke == '1' || smoke == 'true' || smoke == 'yes') {
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          SystemNavigator.pop();
        });
        return;
      }
    } catch (_) {}
  });

  // If DSN is provided, initialize Sentry
  final hasDsn = const String.fromEnvironment('SENTRY_DSN').isNotEmpty;
  final app = ProviderScope(
    overrides: [
      fleetRepositoryProvider.overrideWithValue(
        cfg.useMockData ? MockFleetRepository() : BasicFleetRepository(),
      ),
      supabaseInitializedOverride(initializedSupabase),
      appConfigProvider.overrideWithValue(cfg),
    ],
    child: const TruckerCoreApp(),
  );

  // Capture Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    try {
      Sentry.captureException(details.exception, stackTrace: details.stack);
    } catch (_) {}
  };

  if (hasDsn) {
    await SentryFlutter.init((o) {
      o.dsn = const String.fromEnvironment('SENTRY_DSN');
      o.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      o.enableAutoSessionTracking = true;
      o.attachScreenshot = false;
      o.sendDefaultPii = false;
    });
  }

  // Attach environment tags to Sentry for telemetry correlation
  try {
    await Sentry.configureScope((scope) async {
      scope.setTag('os', Platform.operatingSystem);
      scope.setTag('platform', kIsWeb ? 'web' : 'flutter');
      scope.setTag('app_version', const String.fromEnvironment('APP_VERSION'));
      scope.setTag('git_commit', const String.fromEnvironment('GIT_COMMIT'));
      scope.setTag('channel', const String.fromEnvironment('RELEASE_CHANNEL'));
      scope.setTag('use_mock_data', cfg.useMockData.toString());
    });
  } catch (_) {}

  // Record an app_open analytic event (best-effort)
  try {
    await Sentry.addBreadcrumb(Breadcrumb(
      message: 'app_open',
      category: 'analytics',
      level: SentryLevel.info,
    ));
  } catch (_) {}

  // Run app inside error zone to capture uncaught exceptions (desktop crash telemetry)
  runZonedGuarded(() {
    runApp(app);
  }, (error, stack) {
    try {
      Sentry.captureException(error, stackTrace: stack);
    } catch (_) {}
    try {
      log.e('[crash] Uncaught zone error', error: error, stackTrace: stack);
    } catch (_) {}
  });
}

class TruckerCoreApp extends ConsumerStatefulWidget {
  const TruckerCoreApp({super.key});

  @override
  ConsumerState<TruckerCoreApp> createState() => _TruckerCoreAppState();
}
/*
New Hampshire — Route Planning Data
Low Clearance Locations

US 1 Bypass — Portsmouth → 11’10”

US 3 — Plymouth → 11’9”

NH 85 — Exeter → 11’0”

NH 110A — Milan → 13’0”

NH 119 — Hinsdale, 7.3 mi. north, Connecticut River bridge → 11’10”

NH 175 — Woodstock, over Pemigewasset River → 12’5”

Permanent Weigh/Inspection Stations

I-89 NB, SB — Lebanon, west of exit 18

I-93 NB, SB — Windham, between exit 3 and 4

NH 101 EB, WB — Epping, east of NH 125

Restricted Routes

US 1 — Portsmouth, over Piscataqua River

NH 1B — NH 1A to New Castle

NH 27 — NH 101 to Hampton

NH 103B — Mount Sunapee to Sunapee

NH 109 — Melvin Village to NH 25

NH 109 — Moultonboro to Center Sandwich

NH 113A — NH 113 (North Sandwich) to NH 113 (Tamworth)

NH 123A — NH 123 to NH 10

NH 142 — US 3 to Liscott

NH 171 — NH 109 to Tuftonboro

New Jersey — Route Planning Data
Low Clearance Locations

NJ 4 — Englewood, Jones Rd. overpass, mm 9.62 → 13’1”

NJ 30 — Camden, Baird Blvd. overpass, mm 2.49 → 13’2”

NJ 53 — Denville, mm 4.2 → 12’10”

NJ 73 — Berlin, just north of US 30 → 13’3”

NJ 49 — Bridgeton, north of NJ 49 → 12’10”

I-80 WB — Knowlton, Decatur St. overpass, mm 4.2 → 13’6”

NJ 94 — Hainesburg, Scranton Branch overpass, mm 2.20 → 13’6”

NJ 124 — Madison, under RR tracks → 12’9”

NJ 130 — Brooklawn (south of Gloucester City), mm 25.61 → 13’0”

NJ 439 — Elizabeth, mm 1.93 → 10’7”

NJ 495 — Union City, Hudson Av. overpass, mm 1.85 → 13’6”

Permanent Weigh Stations

I-78 EB, WB — Bloomsbury, mm 6

I-80 EB — 1 mi. east of Pennsylvania line

I-287 NB — Bound Brook, between NJ 18 & NJ 527, mm 9.0

I-295 NB — Carneys Point, mm 3.6

Restricted Routes

US 1/9 (Pulaski Skyway) — I-95 to Jersey City

US 9W — Palisades Interstate Pkwy. to NY line

US 29 — Frenchtown to NJ 129

NJ 52 — Somers Point to Ocean City

NJ 29 — NJ 29 to Pennsylvania line

US 206 — Lawrenceville to Princeton

Garden State Pkwy. — New York line to NJ 18

Holland Tunnel — Weehawken to NY line

Lincoln Tunnel — Weehawken to NY line

Palisades Interstate Pkwy. — NY line to I-95

New Mexico — Route Planning Data
Low Clearance Locations

NM 118 — Gallup, 12.7 mi. east of AZ line at I-40 → 14’0”

NM 118 — Mentmore, 8.4 mi. east of AZ line at I-40 → 13’6”

NM 124 — Grants, 1.2 mi. east of NM 117/124 at I-40 → 13’6”

NM 152 — Kingston, 1.2 mi. east → 12’8”

NM 152 — Kingston, 3.2 mi. east → 12’8”

NM 161 — Watrous, I-25 overpass, exit 364 → 13’11”

NM 465 — Algodones, just west of NM 474 → 13’11”

NM 423 WB — Albuquerque, 0.8 mi. west of 2nd St. → 13’11”

NM 423 WB — Albuquerque, jct. Rio Grande Blvd. → 13’11”

NM 567 — Pilar, 6.1 mi. north of jct. NM 68 at Rio Grande → 12’10”

Permanent Weigh/Inspection Stations

I-10 WB — Anthony, mm 160

I-10/US 70 EB — Lordsburg, 23 mi. east of AZ line, mm 23

I-25/US 85 SB — Raton, 3.0 mi. south of Colorado line (joint POE), mm 460

I-40 EB — Gallup, 15 mi. east of AZ line, mm 12

I-40 EB, WB — San Jon, 20 mi. west of TX line, mm 357

US 54 WB — Nara Visa, 5 mi. SW of TX line, mm 350

US 54 NB — Orogrande, mm 41

US 56 & US 412 WB — Clayton, 9 mi. NW of TX line, mm 430

US 60/70/84 WB — Texico, 1.5 mi. west of TX line, mm 397

US 62/180 WB — Carlsbad, 6 mi. SW, mm 26

US 62/180 WB — Hobbs, 1.5 mi. west of TX line, mm 107

Restricted Routes

(New Mexico has an extensive list — captured key highlights)

NM 1 — US 380 to San Marcial

NM 3 — I-25 to US 54

NM 4 — US 550 to NM 126

NM 9 — Hachita to NM 11

NM 12 — US 180 to Reserve

NM 13 — US 82 to US 285

NM 35 — NM 15 to NM 152

NM 38 — Questa to Eagle Nest

NM 52 — US 60 to I-25 via NM 142

NM 59 — NM 163 to NM 52

NM 75 — NM 68 to NM 518

NM 82 — NM 244 to US 54

NM 137 — US 285 to El Paso Gap

NM 185 — NM 26 to Radium Springs

NM 370 — Clayton to NM 456

NM 392 — NM 469 to I-40

New York — Route Planning Data
Low Clearance Locations

(Statutory height: 14’0” – many posted at 13’11” or less)
Examples (partial list due to large volume):

US 1 — Pelham Manor, Hutchinson River Pkwy. → 12’7”

NY 5 — Albany, north of I-90 → 12’6”

NY 7 — Binghamton, 0.1 mi. north of US 11 → 11’4”

NY 9 — Poughkeepsie, under US 44/NY 55 → 12’9”

NY 27 — Brooklyn, under Pennsylvania Av. → 12’4”

NY 31 — Rochester, 0.9 mi. north of NY 33 → 12’7”

NY 55 — Billings, west of Taconic Pkwy. → 12’9”

NY 117 — Kitchawan, Taconic Pkwy. → 12’9”

NY 141 — Ravena, under I-87 → 12’11”

NY 370 — Liverpool, 1.3 mi. NW of I-81 → 12’0”

I-278 — Brooklyn, under east end of Brooklyn Bridge → 12’3”

Harlem River Dr. — NYC, under 145th St. → 13’7”

Holland Tunnel — NYC, under Hudson River → 12’6”

(Full list extends across multiple pages – all entries can be digitized into database.)

Permanent Weigh/Inspection Stations

None permanent — NY uses portable scales only

Restricted Routes

All Parkways in NY are truck-restricted

NYC — 53’ trailers prohibited except on I-295, I-495, I-695 to/from Long Island

US 9W — NJ line to Nyack

NY 62 — Lackawanna, NY 179 to I-190

NY 117 — Mount Pleasant, Taconic Pkwy. to Pleasantville

NY 213 — Olive Bridge to Atwood

NY 352 — I-86 to NY 414

NY 415 — I-86 to Corning

Lincoln Tunnel, Queensboro Bridge, R. Moses Causeway, Yonkers Av. — truck restrictedNew Hampshire — Route Planning Data
Low Clearance Locations

US 1 Bypass — Portsmouth → 11’10”

US 3 — Plymouth → 11’9”

NH 85 — Exeter → 11’0”

NH 110A — Milan → 13’0”

NH 119 — Hinsdale, 7.3 mi. north, Connecticut River bridge → 11’10”

NH 175 — Woodstock, over Pemigewasset River → 12’5”

Permanent Weigh/Inspection Stations

I-89 NB, SB — Lebanon, west of exit 18

I-93 NB, SB — Windham, between exit 3 and 4

NH 101 EB, WB — Epping, east of NH 125

Restricted Routes

US 1 — Portsmouth, over Piscataqua River

NH 1B — NH 1A to New Castle

NH 27 — NH 101 to Hampton

NH 103B — Mount Sunapee to Sunapee

NH 109 — Melvin Village to NH 25

NH 109 — Moultonboro to Center Sandwich

NH 113A — NH 113 (North Sandwich) to NH 113 (Tamworth)

NH 123A — NH 123 to NH 10

NH 142 — US 3 to Liscott

NH 171 — NH 109 to Tuftonboro

New Jersey — Route Planning Data
Low Clearance Locations

NJ 4 — Englewood, Jones Rd. overpass, mm 9.62 → 13’1”

NJ 30 — Camden, Baird Blvd. overpass, mm 2.49 → 13’2”

NJ 53 — Denville, mm 4.2 → 12’10”

NJ 73 — Berlin, just north of US 30 → 13’3”

NJ 49 — Bridgeton, north of NJ 49 → 12’10”

I-80 WB — Knowlton, Decatur St. overpass, mm 4.2 → 13’6”

NJ 94 — Hainesburg, Scranton Branch overpass, mm 2.20 → 13’6”

NJ 124 — Madison, under RR tracks → 12’9”

NJ 130 — Brooklawn (south of Gloucester City), mm 25.61 → 13’0”

NJ 439 — Elizabeth, mm 1.93 → 10’7”

NJ 495 — Union City, Hudson Av. overpass, mm 1.85 → 13’6”

Permanent Weigh Stations

I-78 EB, WB — Bloomsbury, mm 6

I-80 EB — 1 mi. east of Pennsylvania line

I-287 NB — Bound Brook, between NJ 18 & NJ 527, mm 9.0

I-295 NB — Carneys Point, mm 3.6

Restricted Routes

US 1/9 (Pulaski Skyway) — I-95 to Jersey City

US 9W — Palisades Interstate Pkwy. to NY line

US 29 — Frenchtown to NJ 129

NJ 52 — Somers Point to Ocean City

NJ 29 — NJ 29 to Pennsylvania line

US 206 — Lawrenceville to Princeton

Garden State Pkwy. — New York line to NJ 18

Holland Tunnel — Weehawken to NY line

Lincoln Tunnel — Weehawken to NY line

Palisades Interstate Pkwy. — NY line to I-95

New Mexico — Route Planning Data
Low Clearance Locations

NM 118 — Gallup, 12.7 mi. east of AZ line at I-40 → 14’0”

NM 118 — Mentmore, 8.4 mi. east of AZ line at I-40 → 13’6”

NM 124 — Grants, 1.2 mi. east of NM 117/124 at I-40 → 13’6”

NM 152 — Kingston, 1.2 mi. east → 12’8”

NM 152 — Kingston, 3.2 mi. east → 12’8”

NM 161 — Watrous, I-25 overpass, exit 364 → 13’11”

NM 465 — Algodones, just west of NM 474 → 13’11”

NM 423 WB — Albuquerque, 0.8 mi. west of 2nd St. → 13’11”

NM 423 WB — Albuquerque, jct. Rio Grande Blvd. → 13’11”

NM 567 — Pilar, 6.1 mi. north of jct. NM 68 at Rio Grande → 12’10”

Permanent Weigh/Inspection Stations

I-10 WB — Anthony, mm 160

I-10/US 70 EB — Lordsburg, 23 mi. east of AZ line, mm 23

I-25/US 85 SB — Raton, 3.0 mi. south of Colorado line (joint POE), mm 460

I-40 EB — Gallup, 15 mi. east of AZ line, mm 12

I-40 EB, WB — San Jon, 20 mi. west of TX line, mm 357

US 54 WB — Nara Visa, 5 mi. SW of TX line, mm 350

US 54 NB — Orogrande, mm 41

US 56 & US 412 WB — Clayton, 9 mi. NW of TX line, mm 430

US 60/70/84 WB — Texico, 1.5 mi. west of TX line, mm 397

US 62/180 WB — Carlsbad, 6 mi. SW, mm 26

US 62/180 WB — Hobbs, 1.5 mi. west of TX line, mm 107

Restricted Routes

(New Mexico has an extensive list — captured key highlights)

NM 1 — US 380 to San Marcial

NM 3 — I-25 to US 54

NM 4 — US 550 to NM 126

NM 9 — Hachita to NM 11

NM 12 — US 180 to Reserve

NM 13 — US 82 to US 285

NM 35 — NM 15 to NM 152

NM 38 — Questa to Eagle Nest

NM 52 — US 60 to I-25 via NM 142

NM 59 — NM 163 to NM 52

NM 75 — NM 68 to NM 518

NM 82 — NM 244 to US 54

NM 137 — US 285 to El Paso Gap

NM 185 — NM 26 to Radium Springs

NM 370 — Clayton to NM 456

NM 392 — NM 469 to I-40

New York — Route Planning Data
Low Clearance Locations

(Statutory height: 14’0” – many posted at 13’11” or less)
Examples (partial list due to large volume):

US 1 — Pelham Manor, Hutchinson River Pkwy. → 12’7”

NY 5 — Albany, north of I-90 → 12’6”

NY 7 — Binghamton, 0.1 mi. north of US 11 → 11’4”

NY 9 — Poughkeepsie, under US 44/NY 55 → 12’9”

NY 27 — Brooklyn, under Pennsylvania Av. → 12’4”

NY 31 — Rochester, 0.9 mi. north of NY 33 → 12’7”

NY 55 — Billings, west of Taconic Pkwy. → 12’9”

NY 117 — Kitchawan, Taconic Pkwy. → 12’9”

NY 141 — Ravena, under I-87 → 12’11”

NY 370 — Liverpool, 1.3 mi. NW of I-81 → 12’0”

I-278 — Brooklyn, under east end of Brooklyn Bridge → 12’3”

Harlem River Dr. — NYC, under 145th St. → 13’7”

Holland Tunnel — NYC, under Hudson River → 12’6”

(Full list extends across multiple pages – all entries can be digitized into database.)

Permanent Weigh/Inspection Stations

None permanent — NY uses portable scales only

Restricted Routes

All Parkways in NY are truck-restricted

NYC — 53’ trailers prohibited except on I-295, I-495, I-695 to/from Long Island

US 9W — NJ line to Nyack

NY 62 — Lackawanna, NY 179 to I-190

NY 117 — Mount Pleasant, Taconic Pkwy. to Pleasantville

NY 213 — Olive Bridge to Atwood

NY 352 — I-86 to NY 414

NY 415 — I-86 to Corning

Lincoln Tunnel, Queensboro Bridge, R. Moses Causeway, Yonkers Av. — truck restrictedNew Hampshire — Route Planning Data
Low Clearance Locations

US 1 Bypass — Portsmouth → 11’10”

US 3 — Plymouth → 11’9”

NH 85 — Exeter → 11’0”

NH 110A — Milan → 13’0”

NH 119 — Hinsdale, 7.3 mi. north, Connecticut River bridge → 11’10”

NH 175 — Woodstock, over Pemigewasset River → 12’5”

Permanent Weigh/Inspection Stations

I-89 NB, SB — Lebanon, west of exit 18

I-93 NB, SB — Windham, between exit 3 and 4

NH 101 EB, WB — Epping, east of NH 125

Restricted Routes

US 1 — Portsmouth, over Piscataqua River

NH 1B — NH 1A to New Castle

NH 27 — NH 101 to Hampton

NH 103B — Mount Sunapee to Sunapee

NH 109 — Melvin Village to NH 25

NH 109 — Moultonboro to Center Sandwich

NH 113A — NH 113 (North Sandwich) to NH 113 (Tamworth)

NH 123A — NH 123 to NH 10

NH 142 — US 3 to Liscott

NH 171 — NH 109 to Tuftonboro

New Jersey — Route Planning Data
Low Clearance Locations

NJ 4 — Englewood, Jones Rd. overpass, mm 9.62 → 13’1”

NJ 30 — Camden, Baird Blvd. overpass, mm 2.49 → 13’2”

NJ 53 — Denville, mm 4.2 → 12’10”

NJ 73 — Berlin, just north of US 30 → 13’3”

NJ 49 — Bridgeton, north of NJ 49 → 12’10”

I-80 WB — Knowlton, Decatur St. overpass, mm 4.2 → 13’6”

NJ 94 — Hainesburg, Scranton Branch overpass, mm 2.20 → 13’6”

NJ 124 — Madison, under RR tracks → 12’9”

NJ 130 — Brooklawn (south of Gloucester City), mm 25.61 → 13’0”

NJ 439 — Elizabeth, mm 1.93 → 10’7”

NJ 495 — Union City, Hudson Av. overpass, mm 1.85 → 13’6”

Permanent Weigh Stations

I-78 EB, WB — Bloomsbury, mm 6

I-80 EB — 1 mi. east of Pennsylvania line

I-287 NB — Bound Brook, between NJ 18 & NJ 527, mm 9.0

I-295 NB — Carneys Point, mm 3.6

Restricted Routes

US 1/9 (Pulaski Skyway) — I-95 to Jersey City

US 9W — Palisades Interstate Pkwy. to NY line

US 29 — Frenchtown to NJ 129

NJ 52 — Somers Point to Ocean City

NJ 29 — NJ 29 to Pennsylvania line

US 206 — Lawrenceville to Princeton

Garden State Pkwy. — New York line to NJ 18

Holland Tunnel — Weehawken to NY line

Lincoln Tunnel — Weehawken to NY line

Palisades Interstate Pkwy. — NY line to I-95

New Mexico — Route Planning Data
Low Clearance Locations

NM 118 — Gallup, 12.7 mi. east of AZ line at I-40 → 14’0”

NM 118 — Mentmore, 8.4 mi. east of AZ line at I-40 → 13’6”

NM 124 — Grants, 1.2 mi. east of NM 117/124 at I-40 → 13’6”

NM 152 — Kingston, 1.2 mi. east → 12’8”

NM 152 — Kingston, 3.2 mi. east → 12’8”

NM 161 — Watrous, I-25 overpass, exit 364 → 13’11”

NM 465 — Algodones, just west of NM 474 → 13’11”

NM 423 WB — Albuquerque, 0.8 mi. west of 2nd St. → 13’11”

NM 423 WB — Albuquerque, jct. Rio Grande Blvd. → 13’11”

NM 567 — Pilar, 6.1 mi. north of jct. NM 68 at Rio Grande → 12’10”

Permanent Weigh/Inspection Stations

I-10 WB — Anthony, mm 160

I-10/US 70 EB — Lordsburg, 23 mi. east of AZ line, mm 23

I-25/US 85 SB — Raton, 3.0 mi. south of Colorado line (joint POE), mm 460

I-40 EB — Gallup, 15 mi. east of AZ line, mm 12

I-40 EB, WB — San Jon, 20 mi. west of TX line, mm 357

US 54 WB — Nara Visa, 5 mi. SW of TX line, mm 350

US 54 NB — Orogrande, mm 41

US 56 & US 412 WB — Clayton, 9 mi. NW of TX line, mm 430

US 60/70/84 WB — Texico, 1.5 mi. west of TX line, mm 397

US 62/180 WB — Carlsbad, 6 mi. SW, mm 26

US 62/180 WB — Hobbs, 1.5 mi. west of TX line, mm 107

Restricted Routes

(New Mexico has an extensive list — captured key highlights)

NM 1 — US 380 to San Marcial

NM 3 — I-25 to US 54

NM 4 — US 550 to NM 126

NM 9 — Hachita to NM 11

NM 12 — US 180 to Reserve

NM 13 — US 82 to US 285

NM 35 — NM 15 to NM 152

NM 38 — Questa to Eagle Nest

NM 52 — US 60 to I-25 via NM 142

NM 59 — NM 163 to NM 52

NM 75 — NM 68 to NM 518

NM 82 — NM 244 to US 54

NM 137 — US 285 to El Paso Gap

NM 185 — NM 26 to Radium Springs

NM 370 — Clayton to NM 456

NM 392 — NM 469 to I-40

New York — Route Planning Data
Low Clearance Locations

(Statutory height: 14’0” – many posted at 13’11” or less)
Examples (partial list due to large volume):

US 1 — Pelham Manor, Hutchinson River Pkwy. → 12’7”

NY 5 — Albany, north of I-90 → 12’6”

NY 7 — Binghamton, 0.1 mi. north of US 11 → 11’4”

NY 9 — Poughkeepsie, under US 44/NY 55 → 12’9”

NY 27 — Brooklyn, under Pennsylvania Av. → 12’4”

NY 31 — Rochester, 0.9 mi. north of NY 33 → 12’7”

NY 55 — Billings, west of Taconic Pkwy. → 12’9”

NY 117 — Kitchawan, Taconic Pkwy. → 12’9”

NY 141 — Ravena, under I-87 → 12’11”

NY 370 — Liverpool, 1.3 mi. NW of I-81 → 12’0”

I-278 — Brooklyn, under east end of Brooklyn Bridge → 12’3”

Harlem River Dr. — NYC, under 145th St. → 13’7”

Holland Tunnel — NYC, under Hudson River → 12’6”

(Full list extends across multiple pages – all entries can be digitized into database.)

Permanent Weigh/Inspection Stations

None permanent — NY uses portable scales only

Restricted Routes

All Parkways in NY are truck-restricted

NYC — 53’ trailers prohibited except on I-295, I-495, I-695 to/from Long Island

US 9W — NJ line to Nyack

NY 62 — Lackawanna, NY 179 to I-190

NY 117 — Mount Pleasant, Taconic Pkwy. to Pleasantville

NY 213 — Olive Bridge to Atwood

NY 352 — I-86 to NY 414

NY 415 — I-86 to Corning

Lincoln Tunnel, Queensboro Bridge, R. Moses Causeway, Yonkers Av. — truck restrictedNew Hampshire — Route Planning Data
Low Clearance Locations

US 1 Bypass — Portsmouth → 11’10”

US 3 — Plymouth → 11’9”

NH 85 — Exeter → 11’0”

NH 110A — Milan → 13’0”

NH 119 — Hinsdale, 7.3 mi. north, Connecticut River bridge → 11’10”

NH 175 — Woodstock, over Pemigewasset River → 12’5”

Permanent Weigh/Inspection Stations

I-89 NB, SB — Lebanon, west of exit 18

I-93 NB, SB — Windham, between exit 3 and 4

NH 101 EB, WB — Epping, east of NH 125

Restricted Routes

US 1 — Portsmouth, over Piscataqua River

NH 1B — NH 1A to New Castle

NH 27 — NH 101 to Hampton

NH 103B — Mount Sunapee to Sunapee

NH 109 — Melvin Village to NH 25

NH 109 — Moultonboro to Center Sandwich

NH 113A — NH 113 (North Sandwich) to NH 113 (Tamworth)

NH 123A — NH 123 to NH 10

NH 142 — US 3 to Liscott

NH 171 — NH 109 to Tuftonboro

New Jersey — Route Planning Data
Low Clearance Locations

NJ 4 — Englewood, Jones Rd. overpass, mm 9.62 → 13’1”

NJ 30 — Camden, Baird Blvd. overpass, mm 2.49 → 13’2”

NJ 53 — Denville, mm 4.2 → 12’10”

NJ 73 — Berlin, just north of US 30 → 13’3”

NJ 49 — Bridgeton, north of NJ 49 → 12’10”

I-80 WB — Knowlton, Decatur St. overpass, mm 4.2 → 13’6”

NJ 94 — Hainesburg, Scranton Branch overpass, mm 2.20 → 13’6”

NJ 124 — Madison, under RR tracks → 12’9”

NJ 130 — Brooklawn (south of Gloucester City), mm 25.61 → 13’0”

NJ 439 — Elizabeth, mm 1.93 → 10’7”

NJ 495 — Union City, Hudson Av. overpass, mm 1.85 → 13’6”

Permanent Weigh Stations

I-78 EB, WB — Bloomsbury, mm 6

I-80 EB — 1 mi. east of Pennsylvania line

I-287 NB — Bound Brook, between NJ 18 & NJ 527, mm 9.0

I-295 NB — Carneys Point, mm 3.6

Restricted Routes

US 1/9 (Pulaski Skyway) — I-95 to Jersey City

US 9W — Palisades Interstate Pkwy. to NY line

US 29 — Frenchtown to NJ 129

NJ 52 — Somers Point to Ocean City

NJ 29 — NJ 29 to Pennsylvania line

US 206 — Lawrenceville to Princeton

Garden State Pkwy. — New York line to NJ 18

Holland Tunnel — Weehawken to NY line

Lincoln Tunnel — Weehawken to NY line

Palisades Interstate Pkwy. — NY line to I-95

New Mexico — Route Planning Data
Low Clearance Locations

NM 118 — Gallup, 12.7 mi. east of AZ line at I-40 → 14’0”

NM 118 — Mentmore, 8.4 mi. east of AZ line at I-40 → 13’6”

NM 124 — Grants, 1.2 mi. east of NM 117/124 at I-40 → 13’6”

NM 152 — Kingston, 1.2 mi. east → 12’8”

NM 152 — Kingston, 3.2 mi. east → 12’8”

NM 161 — Watrous, I-25 overpass, exit 364 → 13’11”

NM 465 — Algodones, just west of NM 474 → 13’11”

NM 423 WB — Albuquerque, 0.8 mi. west of 2nd St. → 13’11”

NM 423 WB — Albuquerque, jct. Rio Grande Blvd. → 13’11”

NM 567 — Pilar, 6.1 mi. north of jct. NM 68 at Rio Grande → 12’10”

Permanent Weigh/Inspection Stations

I-10 WB — Anthony, mm 160

I-10/US 70 EB — Lordsburg, 23 mi. east of AZ line, mm 23

I-25/US 85 SB — Raton, 3.0 mi. south of Colorado line (joint POE), mm 460

I-40 EB — Gallup, 15 mi. east of AZ line, mm 12

I-40 EB, WB — San Jon, 20 mi. west of TX line, mm 357

US 54 WB — Nara Visa, 5 mi. SW of TX line, mm 350

US 54 NB — Orogrande, mm 41

US 56 & US 412 WB — Clayton, 9 mi. NW of TX line, mm 430

US 60/70/84 WB — Texico, 1.5 mi. west of TX line, mm 397

US 62/180 WB — Carlsbad, 6 mi. SW, mm 26

US 62/180 WB — Hobbs, 1.5 mi. west of TX line, mm 107

Restricted Routes

(New Mexico has an extensive list — captured key highlights)

NM 1 — US 380 to San Marcial

NM 3 — I-25 to US 54

NM 4 — US 550 to NM 126

NM 9 — Hachita to NM 11

NM 12 — US 180 to Reserve

NM 13 — US 82 to US 285

NM 35 — NM 15 to NM 152

NM 38 — Questa to Eagle Nest

NM 52 — US 60 to I-25 via NM 142

NM 59 — NM 163 to NM 52

NM 75 — NM 68 to NM 518

NM 82 — NM 244 to US 54

NM 137 — US 285 to El Paso Gap

NM 185 — NM 26 to Radium Springs

NM 370 — Clayton to NM 456

NM 392 — NM 469 to I-40

New York — Route Planning Data
Low Clearance Locations

(Statutory height: 14’0” – many posted at 13’11” or less)
Examples (partial list due to large volume):

US 1 — Pelham Manor, Hutchinson River Pkwy. → 12’7”

NY 5 — Albany, north of I-90 → 12’6”

NY 7 — Binghamton, 0.1 mi. north of US 11 → 11’4”

NY 9 — Poughkeepsie, under US 44/NY 55 → 12’9”

NY 27 — Brooklyn, under Pennsylvania Av. → 12’4”

NY 31 — Rochester, 0.9 mi. north of NY 33 → 12’7”

NY 55 — Billings, west of Taconic Pkwy. → 12’9”

NY 117 — Kitchawan, Taconic Pkwy. → 12’9”

NY 141 — Ravena, under I-87 → 12’11”

NY 370 — Liverpool, 1.3 mi. NW of I-81 → 12’0”

I-278 — Brooklyn, under east end of Brooklyn Bridge → 12’3”

Harlem River Dr. — NYC, under 145th St. → 13’7”

Holland Tunnel — NYC, under Hudson River → 12’6”

(Full list extends across multiple pages – all entries can be digitized into database.)

Permanent Weigh/Inspection Stations

None permanent — NY uses portable scales only

Restricted Routes

All Parkways in NY are truck-restricted

NYC — 53’ trailers prohibited except on I-295, I-495, I-695 to/from Long Island

US 9W — NJ line to Nyack

NY 62 — Lackawanna, NY 179 to I-190

NY 117 — Mount Pleasant, Taconic Pkwy. to Pleasantville

NY 213 — Olive Bridge to Atwood

NY 352 — I-86 to NY 414

NY 415 — I-86 to Corning

Lincoln Tunnel, Queensboro Bridge, R. Moses Causeway, Yonkers Av. — truck restricted
*/

class _TruckerCoreAppState extends ConsumerState<TruckerCoreApp> with WidgetsBindingObserver {
  late final go.GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = buildAppRouter(supabaseReady: ref.read(supabaseReadyProvider));
  }

  ThemeData _buildDarkTheme() {
    // Slightly darker overall UI while keeping AA+ contrast for body text
    const baseBg = Color(0xFF12161B); // target ~#0F1216–#12161B
    const surface = Color(0xFF1A1F26); // one step lighter than background
    const muted = Color(
      0xFF2A313A,
    ); // 10–15% lighter than background for outlines

    final darkScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF58A6FF),
      onPrimary: Colors.black,
      secondary: Color(0xFF79C0FF),
      onSecondary: Colors.black,
      tertiary: Color(0xFF34D399),
      onTertiary: Colors.black,
      error: Color(0xFFFF6B6B),
      onError: Colors.black,
      // Use surface/onSurface instead of deprecated background/onBackground
      surface: surface,
      onSurface: Colors.white,
      // Replace deprecated surfaceVariant with surfaceContainerHighest
      surfaceContainerHighest: muted,
      outline: muted,
      surfaceTint: Color(0xFF58A6FF),
    );

    final t = ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: baseBg,
      cardColor: surface,
      // Use withValues instead of deprecated withOpacity
      dividerColor: muted.withValues(alpha: 0.6),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161B22),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );

    return t;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // propagate lifecycle to refresh orchestrator so polling pauses in background
    ref.read(appLifecycleStateProvider.notifier).state = state;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TruckerCore',
      theme: _buildDarkTheme(),
      routerConfig: _router,
      builder: (context, child) {
        return HeroControllerScope.none(
          child: Consumer(
            builder: (context, ref, _) {
              final isOnline = ref.watch(connectivityStatusProvider);
              final flags = ref.watch(rolloutFlagsProvider);
              return OfflineBanner(
                backendReady: ref.watch(supabaseReadyProvider),
                isOnline: isOnline,
                child: flags.statusBannerEnabled
                    ? StatusBanner(
                        child: PilotBanner(child: AppBackground(child: child ?? const SizedBox.shrink())),
                      )
                    : PilotBanner(child: AppBackground(child: child ?? const SizedBox.shrink())),
              );
            },
          ),
        );
      },
    );
  }
}


Future<void> _initializeSupabaseForDashboard() async {
  try {
    if (!kIsWeb) {
      await dotenv.load();
    }
  } catch (_) {}

  AppEnv.maybeWarnLegacy();

  String envOrEmpty(String key) {
    try {
      final v = dotenv.maybeGet(key);
      return v ?? '';
    } catch (_) {
      return '';
    }
  }

  final ddUrl = AppEnv.supabaseUrl;
  final ddAnon = AppEnv.supabaseAnonKey;
  final envUrl = envOrEmpty('SUPABASE_URL');
  final envAnonNew = envOrEmpty('SUPABASE_ANON');
  final envAnonLegacy = envOrEmpty('SUPABASE_ANON_KEY');

  final supabaseUrlEnv = ddUrl.isNotEmpty ? ddUrl : (envUrl.isNotEmpty ? envUrl : appConfigFromEnv.supabaseUrl);
  final supabaseAnonEnv = ddAnon.isNotEmpty
      ? ddAnon
      : (envAnonNew.isNotEmpty
          ? envAnonNew
          : envAnonLegacy.isNotEmpty
              ? envAnonLegacy
              : appConfigFromEnv.supabaseAnonKey);

  if (supabaseUrlEnv.isNotEmpty && supabaseAnonEnv.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrlEnv, anonKey: supabaseAnonEnv);
    log.i('[dashboard] Supabase initialized');
  } else {
    log.w('[dashboard] Supabase not initialized (missing URL or anon key)');
  }
}
