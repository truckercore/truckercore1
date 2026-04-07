import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:truckercore1/core/logging/app_logger.dart' as app_log;
import 'package:truckercore1/features/tracking/tracking_service.dart';

import '../../../common/config/app_config.dart';
import '../../../common/state/session_provider.dart';
import '../../../common/utils/retry.dart';
import '../../../common/widgets/app_background.dart';
import '../../../common/widgets/role_badge.dart';
import '../../../common/widgets/switch_role_menu.dart';
import '../../../services/supabase_safe.dart';
import '../../../utils/time.dart' show TimeFmt;
import '../../../widgets/loading_action_button.dart';
import '../../alerts/alerts_drawer.dart';
import '../../compliance/widgets/compliance_alerts_panel.dart';
import '../../documents/documents_service.dart';
import '../../driver/hos/hos_controls.dart' show HosControls;
import '../../fleet/services/telemetry_service.dart';
import '../../maps/restrictions_service.dart';
import '../../profile/driver_vehicle_settings.dart';
import '../../safety/weigh_stations.dart';
import '../widgets/app_bar_more_menu.dart';
import '../widgets/assigned_deliveries_card.dart';
import '../widgets/layers_sheet.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

final _quietModeProvider = StateProvider<bool>((ref) => false);

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen> {
  RealtimeChannel? _loadsChan;
  void _subscribeAssignedLoads() {
    try {
      final cfg = ref.read(appConfigProvider);
      final ready =
          cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
      final client = ready ? SupabaseSafe.clientOrNull : null;
      final user = client?.auth.currentUser;
      if (client == null || user == null) return;
      _loadsChan = client.channel('realtime:loads_assigned_${user.id}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'loads',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_driver_id',
            value: user.id,
          ),
          callback: (_) {
            if (mounted) setState(() {});
          },
        )
        ..subscribe();
    } catch (e) {
      app_log.AppLogger.error('[realtime] loads subscribe error', e);
    }
  }

  @override
  void initState() {
    super.initState();
    // [mounted] log for DevTools verification
    app_log.AppLogger.info('[mounted] DriverDashboardScreen');
    // Ensure controller initialized
    ref.read(activeTripControllerProvider);
    _subscribeAssignedLoads();
    // Load last persisted latest calc for active trip on open
    Future.microtask(() async {
      await _loadLatestCalc(ref);
      // Prefill planner options from saved driver/vehicle profile
      try {
        final notifier = ref.read(driverVehicleProfileProvider.notifier);
        await notifier.load();
        final prof = ref.read(driverVehicleProfileProvider);
        final st = ref.read(_plannerProvider);
        ref.read(_plannerProvider.notifier).state = st.copyWith(
          hazmat: prof.hazmatClasses.isNotEmpty,
          avoidTolls: prof.avoidTollsDefault,
          trafficOn: prof.trafficDefault,
        );
      } catch (e) {
        app_log.AppLogger.warn('[driver] prefill planner from profile failed', e);
      }
      // Route polyline now provided by tripRouteStreamProvider (no manual seeding)
    });
  }

  bool showTraffic = true; // stub toggle
  bool showWeather = false; // stub toggle

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryServiceProvider);
    final isPremium = ref.watch(sessionProvider).isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          if (isPremium)
            IconButton(
              tooltip: 'RoadDogg Assistant',
              icon: const Icon(Icons.smart_toy_outlined),
              onPressed: () => context.push('/roaddogg'),
            ),
          const SwitchRoleMenu(),
          const SizedBox(width: 8),
          Consumer(
            builder: (context, ref, _) {
              final quiet = ref.watch(_quietModeProvider);
              return IconButton(
                tooltip: quiet ? 'Quiet mode: On' : 'Quiet mode: Off',
                icon: Icon(
                  quiet ? Icons.nightlight_round : Icons.nights_stay_outlined,
                ),
                onPressed: () =>
                    ref.read(_quietModeProvider.notifier).state = !quiet,
              );
            },
          ),
          const AlertsBell(),
          AppBarMoreMenu(
            onDotInspection: () {
              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (ctx) => const _DotInspectionSheet(preTrip: true),
              );
            },
            onRoutePlanning: () => context.push('/route-planning'),
            onLogout: () async {
              try {
                final c = SupabaseSafe.clientOrNull;
                if (c != null) {
                  await c.auth.signOut();
                }
              } catch (e) {
                app_log.AppLogger.error('[auth] signOut failed', e);
              }
              if (!context.mounted) return;
              context.go('/auth/login');
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: RoleBadge()),
          ),
        ],
      ),
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Active Trip badge
              const _ActiveTripBadge(),
              const SizedBox(height: 8),
              // HOS Snapshot + Controls
              const _HosSnapshotCard(),
              const SizedBox(height: 6),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HOS Controls',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 6),
                      // Compact toggle bar
                      SizedBox(height: 48, child: _HosControlsEmbed()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Trip controls (Start/Pause/Resume/End)
              const _TripControlsCard(),
              const SizedBox(height: 12),
              // Driver Tracking MVP controls
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined),
                      const SizedBox(width: 8),
                      const Text('Tracking'),
                      const SizedBox(width: 12),
                      Consumer(builder: (context, ref, _) {
                        final state = ref.watch(trackingControllerProvider);
                        final ctrl = ref.read(trackingControllerProvider.notifier);
                        return Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: state == TrackingState.running ? null : () => ctrl.start(),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start'),
                            ),
                            OutlinedButton.icon(
                              onPressed: state == TrackingState.running ? () => ctrl.pause() : null,
                              icon: const Icon(Icons.pause),
                              label: const Text('Pause'),
                            ),
                            OutlinedButton.icon(
                              onPressed: state == TrackingState.paused ? () => ctrl.resume() : null,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Resume'),
                            ),
                            Text('State: ${state.name}')
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Map Canvas with live location
              SizedBox(
                height: 240,
                child: FutureBuilder<List<TruckPosition>>(
                  future: telemetry.listCurrentPositions(),
                  builder: (context, snap) {
                    final pos =
                        (snap.data ?? const <TruckPosition>[]).firstOrNull;
                    final center = pos != null
                        ? LatLng(pos.lat, pos.lng)
                        : const LatLng(39.5, -98.35);
                    return Stack(
                      children: [
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: center,
                              initialZoom: 6,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.truckercore.app',
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          right: 16,
                          bottom: 16,
                          child: LayersSheetButton(),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Safety banners
              const _SafetyCoachCard(),
              const SizedBox(height: 12),
              const _WeighStationBanner(),
              const SizedBox(height: 12),

              // Compliance Alerts (route-aware)
              const ComplianceAlertsPanel(),
              const SizedBox(height: 12),

              // Route Planner Panel (basic stub)
              const _RoutePlannerCard(),
              const SizedBox(height: 12),

              // Trip Summary Card (derived from planner state)
              const _TripSummaryCard(),
              const SizedBox(height: 12),

              // Fuel & Spend (My logs)
              const _FuelSpendMyLogsCard(),
              const SizedBox(height: 12),

              // Help & Training + Support Tickets
              const _HelpTrainingCard(),
              const SizedBox(height: 8),
              const _SupportTicketsCard(),
              const SizedBox(height: 12),

              // Assigned Deliveries (today/upcoming)
              const AssignedDeliveriesCard(),
              const SizedBox(height: 12),

              // Quick actions row
              Row(
                children: [
                  Expanded(
                    child: LoadingActionButton(
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.fact_check), SizedBox(width: 8), Text('Pre-Trip')]),
                      onPressed: () async {
                        final ok = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) =>
                              const _DotInspectionSheet(preTrip: true),
                        );
                        if (ok == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pre-trip submitted.'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LoadingActionButton(
                      style: OutlinedButton.styleFrom(),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.note_alt), SizedBox(width: 8), Text('Post-Trip')]),
                      onPressed: () async {
                        final ok = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) =>
                              const _DotInspectionSheet(preTrip: false),
                        );
                        if (ok == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Post-trip submitted.'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload BOL/Docs'),
                      onPressed: () {
                        app_log.AppLogger.info('[click] Upload BOL/Docs');
                        context.push('/documents');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.mic),
                      label: const Text('Voice Actions'),
                      onPressed: () => _showStub(
                        context,
                        'Say: "Start navigation" or "Mark arrived"',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.settings_suggest),
                      label: const Text('Driver & Vehicle Settings'),
                      onPressed: () => context.push('/settings/driver-vehicle'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Trip History
              const _TripHistoryCard(),
              const SizedBox(height: 12),

              // Notification center (trip alerts)
              const _NotificationsCard(),
              const SizedBox(height: 12),

              // Deadhead and Pay Snapshot (stubs)
              const _DeadheadAndPayCard(),
              const SizedBox(height: 12),

              // Ads banner only for Free tier (no plan/upsell banners in dashboard)
              if (!isPremium) const _FreeTierAdsBanner(),
              const SizedBox(height: 8),
              const _HealthFooter(),
            ],
          ), // end ListView
        ), // end RefreshIndicator
      ), // end AppBackground
    ); // end Scaffold
  }

  @override
  void dispose() {
    try {
      _loadsChan?.unsubscribe();
    } catch (e) {
      app_log.AppLogger.warn('[realtime] unsubscribe error', e);
    }
    super.dispose();
  }

  void _showStub(BuildContext context, String msg) {
    app_log.AppLogger.info('[click] $msg');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// Simple planner state (in-memory only for MVP stub)
final _plannerProvider = StateProvider<_PlanState>((ref) => const _PlanState());

class _PlanState {
  final String? origin;
  final String? destination;
  final bool hazmat;
  final bool avoidTolls;
  final bool trafficOn;
  final double? distanceMiles;
  final Duration? eta;
  final bool calculating;
  final DateTime? lastCalculatedAt;
  final DateTime? lastTrafficUpdatedAt;
  final String? inputHash;
  final int routeVersion;
  const _PlanState({
    this.origin,
    this.destination,
    this.hazmat = false,
    this.avoidTolls = false,
    this.trafficOn = true,
    this.distanceMiles,
    this.eta,
    this.calculating = false,
    this.lastCalculatedAt,
    this.lastTrafficUpdatedAt,
    this.inputHash,
    this.routeVersion = 0,
  });
  _PlanState copyWith({
    String? origin,
    String? destination,
    bool? hazmat,
    bool? avoidTolls,
    bool? trafficOn,
    double? distanceMiles,
    Duration? eta,
    bool? calculating,
    DateTime? lastCalculatedAt,
    DateTime? lastTrafficUpdatedAt,
    String? inputHash,
    int? routeVersion,
  }) => _PlanState(
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    hazmat: hazmat ?? this.hazmat,
    avoidTolls: avoidTolls ?? this.avoidTolls,
    trafficOn: trafficOn ?? this.trafficOn,
    distanceMiles: distanceMiles ?? this.distanceMiles,
    eta: eta ?? this.eta,
    calculating: calculating ?? this.calculating,
    lastCalculatedAt: lastCalculatedAt ?? this.lastCalculatedAt,
    lastTrafficUpdatedAt: lastTrafficUpdatedAt ?? this.lastTrafficUpdatedAt,
    inputHash: inputHash ?? this.inputHash,
    routeVersion: routeVersion ?? this.routeVersion,
  );
}

class _RoutePlannerCard extends ConsumerStatefulWidget {
  const _RoutePlannerCard();
  @override
  ConsumerState<_RoutePlannerCard> createState() => _RoutePlannerCardState();
}

class _RoutePlannerCardState extends ConsumerState<_RoutePlannerCard> {
  late final TextEditingController originCtrl;
  late final TextEditingController destCtrl;

  @override
  void initState() {
    super.initState();
    final st = ref.read(_plannerProvider);
    originCtrl = TextEditingController(text: st.origin ?? '');
    destCtrl = TextEditingController(text: st.destination ?? '');
  }

  @override
  void dispose() {
    originCtrl.dispose();
    destCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(_plannerProvider);

    final isBlitz = ref.watch(isBlitzDayProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBlitz)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Inspection Blitz Week — extra patrols likely',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            const Row(
              children: [
                Icon(Icons.alt_route),
                SizedBox(width: 8),
                Text(
                  'Route Planner',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Origin',
                isDense: true,
              ),
              controller: originCtrl,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Destination',
                isDense: true,
              ),
              controller: destCtrl,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilterChip(
                  label: const Text('Hazmat'),
                  selected: st.hazmat,
                  onSelected: (v) async {
                    final s1 = st.copyWith(hazmat: v);
                    ref.read(_plannerProvider.notifier).state = s1;
                    await _recalculate(context, ref, s1);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Avoid tolls'),
                  selected: st.avoidTolls,
                  onSelected: (v) async {
                    final s1 = st.copyWith(avoidTolls: v);
                    ref.read(_plannerProvider.notifier).state = s1;
                    await _recalculate(context, ref, s1);
                  },
                ),
                const Spacer(),
                LoadingActionButton(
                  style: OutlinedButton.styleFrom(),
                  initiallyEnabled: !st.calculating,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.refresh), SizedBox(width: 8), Text('Recalculate')]),
                  onPressed: () async {
                    app_log.AppLogger.info('[click] Planner: Recalculate');
                    FocusScope.of(context).unfocus();
                    final s1 = st.copyWith(
                      origin: originCtrl.text.trim().isEmpty ? null : originCtrl.text.trim(),
                      destination: destCtrl.text.trim().isEmpty ? null : destCtrl.text.trim(),
                    );
                    ref.read(_plannerProvider.notifier).state = s1;
                    await _recalculate(context, ref, s1, manual: true);
                  },
                ),
                const SizedBox(width: 8),
                LoadingActionButton(
                  initiallyEnabled: !st.calculating && originCtrl.text.trim().isNotEmpty && destCtrl.text.trim().isNotEmpty,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.directions), SizedBox(width: 8), Text('Plan')]),
                  onPressed: () async {
                    app_log.AppLogger.info('[click] Planner: Plan');
                    FocusScope.of(context).unfocus();
                    final s1 = st.copyWith(
                      origin: originCtrl.text.trim().isEmpty ? null : originCtrl.text.trim(),
                      destination: destCtrl.text.trim().isEmpty ? null : destCtrl.text.trim(),
                    );
                    ref.read(_plannerProvider.notifier).state = s1;
                    await _recalculate(context, ref, s1, manual: true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // MVP: weigh-station DIY + approach evaluation
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.monitor_weight),
                  label: const Text('Report OPEN'),
                  onPressed: () {
                    app_log.AppLogger.info('[click] Weigh Station: Report OPEN');
                    final actions = ref.read(weighStationsActionsProvider);
                    // Just pick first station near planner dest as placeholder
                    final stations = ref.read(weighStationsProvider);
                    if (stations.isNotEmpty) {
                      actions.report(stations.first.id, WeighStatus.open);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Thanks! Recorded OPEN.')),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.monitor_weight_outlined),
                  label: const Text('Report CLOSED'),
                  onPressed: () {
                    // ignore: avoid_print
                    print('[click] Weigh Station: Report CLOSED');
                    final actions = ref.read(weighStationsActionsProvider);
                    final stations = ref.read(weighStationsProvider);
                    if (stations.isNotEmpty) {
                      actions.report(stations.first.id, WeighStatus.closed);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thanks! Recorded CLOSED.'),
                        ),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.notification_important),
                  label: const Text('Evaluate Approaching'),
                  onPressed: () async {
                    app_log.AppLogger.info('[click] Weigh Station: Evaluate Approaching');
                    // For MVP, assume current center from telemetry first position
                    final telemetry = ref.read(telemetryServiceProvider);
                    final positions = await telemetry.listCurrentPositions();
                    final p = positions.isNotEmpty ? positions.first : null;
                    final lat = p?.lat ?? 39.5;
                    final lng = p?.lng ?? -98.35;
                    ref
                        .read(approachAlertsProvider.notifier)
                        .evaluateApproach(
                          currLat: lat,
                          currLng: lng,
                          avgSpeedMph: 55,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checked stations on route.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripSummaryCard extends ConsumerWidget {
  const _TripSummaryCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(_plannerProvider);
    final missing = st.origin == null || st.destination == null;
    final micro = st.lastCalculatedAt == null
        ? 'Not calculated yet'
        : 'Last calculated ${_timeFmt(st.lastCalculatedAt!)} • Traffic updated ${_ageStr(st.lastTrafficUpdatedAt ?? st.lastCalculatedAt!)} ago';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.summarize),
                SizedBox(width: 8),
                Text(
                  'Trip Summary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (missing)
              const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber),
                  SizedBox(width: 6),
                  Expanded(child: Text('Add both points to calculate.')),
                ],
              )
            else if (st.calculating)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Recalculating…'),
                ],
              )
            else
              Text(
                'Distance: ${st.distanceMiles?.toStringAsFixed(0) ?? '—'} mi • ETA: ${_fmtDur(st.eta)} • Hazmat: ${st.hazmat ? 'Yes' : 'No'} • Avoid tolls: ${st.avoidTolls ? 'Yes' : 'No'}',
              ),
            const SizedBox(height: 6),
            Text(micro, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String _fmtDur(Duration? d) {
    if (d == null) return '—';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '$h h ${m}m';
  }

  String _ageStr(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }

  String _timeFmt(DateTime t) {
    final lt = t.toLocal();
    final h = lt.hour % 12 == 0 ? 12 : lt.hour % 12;
    final m = lt.minute.toString().padLeft(2, '0');
    final ampm = lt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

Future<void> _persistTripSummary(WidgetRef ref, _PlanState st) async {
  try {
    final c = Supabase.instance.client;
    final active = ref.read(activeTripControllerProvider);
    final details = {
      'origin': st.origin,
      'destination': st.destination,
      'hazmat': st.hazmat,
      'avoid_tolls': st.avoidTolls,
      'distance_miles': st.distanceMiles,
      'eta_minutes': st.eta?.inMinutes,
      'trip_id': active.tripId,
      'truck_id': active.truckId,
    };
    // write as a dispatch_event note if tables exist; ignore errors if not configured
    await c.from('dispatch_events').insert({
      'event_type': 'trip_summary',
      'details': details,
    });
  } catch (_) {
    // ignore in demo
  }
}

class _DeadheadAndPayCard extends StatelessWidget {
  const _DeadheadAndPayCard();
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deadhead & Pay Snapshot',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Deadhead: ~45 mi (stub) • Pay: \$0.65/mi (stub)'),
          ],
        ),
      ),
    );
  }
}

class _SafetyCoachCard extends StatelessWidget {
  const _SafetyCoachCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.shield, color: Colors.orange),
        title: const Text('Safety Coach'),
        subtitle: const Text(
          'Gentle nudges: speeding, hard brakes, sharp turns. Trip score 86 • Weekly +4',
        ),
        trailing: TextButton(
          child: const Text('Details'),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Safety details coming soon')),
          ),
        ),
      ),
    );
  }
}

// ===== Active Trip State & Controls =====

enum _TripStatus { idle, active, paused }

class _ActiveTripState {
  final String? tripId;
  final String? truckId;
  final _TripStatus status;
  final DateTime? startedAt;
  final DateTime? lastPingAt;
  final DateTime? endedAt;
  const _ActiveTripState({
    this.tripId,
    this.truckId,
    this.status = _TripStatus.idle,
    this.startedAt,
    this.lastPingAt,
    this.endedAt,
  });
  bool get isActive => status == _TripStatus.active;
  bool get isPaused => status == _TripStatus.paused;
  _ActiveTripState copyWith({
    String? tripId,
    String? truckId,
    _TripStatus? status,
    DateTime? startedAt,
    DateTime? lastPingAt,
    DateTime? endedAt,
  }) => _ActiveTripState(
    tripId: tripId ?? this.tripId,
    truckId: truckId ?? this.truckId,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    lastPingAt: lastPingAt ?? this.lastPingAt,
    endedAt: endedAt ?? this.endedAt,
  );
}

class _EndedTrip {
  final String tripId;
  final DateTime startedAt;
  final DateTime endedAt;
  final String? truckId;
  const _EndedTrip({
    required this.tripId,
    required this.startedAt,
    required this.endedAt,
    this.truckId,
  });
}

final _endedTripsProvider = StateProvider<List<_EndedTrip>>((ref) => const []);

class _ActiveTripController extends StateNotifier<_ActiveTripState> {
  _ActiveTripController(this._ref) : super(const _ActiveTripState());
  final Ref _ref;
  Timer? _timer;

  Future<String?> _detectTruckId() async {
    final telem = _ref.read(telemetryServiceProvider);
    final list = await telem.listCurrentPositions();
    return list.isNotEmpty ? list.first.truckId : null;
  }

  Future<void> start() async {
    final truckId = await _detectTruckId();
    final tripId = 'trip_${DateTime.now().millisecondsSinceEpoch}';
    state = _ActiveTripState(
      tripId: tripId,
      truckId: truckId,
      status: _TripStatus.active,
      startedAt: DateTime.now(),
    );
    // Persist state change
    try {
      final c = Supabase.instance.client;
      await c.from('dispatch_events').insert({
        'event_type': 'trip_state',
        'details': {
          'trip_id': tripId,
          'truck_id': truckId,
          'state': 'start',
          'ts': DateTime.now().toUtc().toIso8601String(),
        },
      });
    } catch (_) {}
    // Persist current calculation as baseline_*
    try {
      final st = _ref.read(_plannerProvider);
      await _persistTripCalcBaseline(_ref, st);
    } catch (_) {}
    _startTicker();
  }

  void pause() {
    if (!state.isActive) return;
    state = state.copyWith(status: _TripStatus.paused);
    try {
      final c = Supabase.instance.client;
      c.from('dispatch_events').insert({
        'event_type': 'trip_state',
        'details': {
          'trip_id': state.tripId,
          'truck_id': state.truckId,
          'state': 'pause',
          'ts': DateTime.now().toUtc().toIso8601String(),
        },
      });
    } catch (_) {}
  }

  void resume() {
    if (!state.isPaused) return;
    state = state.copyWith(status: _TripStatus.active);
    try {
      final c = Supabase.instance.client;
      c.from('dispatch_events').insert({
        'event_type': 'trip_state',
        'details': {
          'trip_id': state.tripId,
          'truck_id': state.truckId,
          'state': 'resume',
          'ts': DateTime.now().toUtc().toIso8601String(),
        },
      });
    } catch (_) {}
  }

  void resumeLast() {
    if (state.tripId != null && !state.isActive && !state.isPaused) {
      state = state.copyWith(status: _TripStatus.active);
      _startTicker();
    }
  }

  void end() {
    _timer?.cancel();
    _timer = null;
    final endedAt = DateTime.now();
    final s = state;
    if (s.tripId != null && s.startedAt != null) {
      final list = List<_EndedTrip>.from(_ref.read(_endedTripsProvider));
      list.insert(
        0,
        _EndedTrip(
          tripId: s.tripId!,
          startedAt: s.startedAt!,
          endedAt: endedAt,
          truckId: s.truckId,
        ),
      );
      _ref.read(_endedTripsProvider.notifier).state = list;
      try {
        final c = Supabase.instance.client;
        c.from('dispatch_events').insert({
          'event_type': 'trip_state',
          'details': {
            'trip_id': s.tripId,
            'truck_id': s.truckId,
            'state': 'end',
            'ts': DateTime.now().toUtc().toIso8601String(),
          },
        });
      } catch (_) {}
    }
    state = state.copyWith(status: _TripStatus.idle, endedAt: endedAt);
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    _tick();
  }

  Future<void> _tick() async {
    final s = state;
    if (s.tripId == null || s.truckId == null) {
      state = s.copyWith(lastPingAt: DateTime.now());
      return;
    }
    if (!s.isActive) return;
    try {
      // Use last known server position for the truck (as a proxy for device GPS in this MVP)
      final telem = _ref.read(telemetryServiceProvider);
      final pos = await telem.listCurrentPositions();
      TruckPosition? p = pos.where((e) => e.truckId == s.truckId).firstOrNull;
      p ??= pos.firstOrNull;
      if (p != null) {
        await telem.ingestPosition(
          truckId: s.truckId!,
          lat: p.lat,
          lng: p.lng,
          speedKph: p.speedKph,
          headingDeg: p.headingDeg,
          gpsTs: DateTime.now().toUtc(),
          source: 'driver_app',
          tripId: s.tripId,
        );
        // Re-evaluate approach every tick (~15s) using current position
        final mph =
            (p.speedKph ?? 80) * 0.621371; // fallback typical highway speed
        // ignore if absurdly low
        final latNow = p.lat;
        final lngNow = p.lng;
        final mphClamped = mph.clamp(5, 80).toDouble();
        Future.microtask(
          () => _ref
              .read(approachAlertsProvider.notifier)
              .evaluateApproach(
                currLat: latNow,
                currLng: lngNow,
                avgSpeedMph: mphClamped,
              ),
        );
      }
      state = s.copyWith(lastPingAt: DateTime.now());
    } catch (_) {
      state = s.copyWith(lastPingAt: DateTime.now());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final activeTripControllerProvider =
    StateNotifierProvider<_ActiveTripController, _ActiveTripState>((ref) {
      return _ActiveTripController(ref);
    });

class _ActiveTripBadge extends ConsumerWidget {
  const _ActiveTripBadge();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(activeTripControllerProvider);
    final age = st.lastPingAt == null ? '—' : _ageStr(st.lastPingAt!);
    final color = st.isActive
        ? Colors.green
        : (st.isPaused ? Colors.amber : Colors.grey);
    return Row(
      children: [
        Chip(
          avatar: Icon(
            st.isActive
                ? Icons.play_arrow
                : st.isPaused
                ? Icons.pause
                : Icons.stop,
            color: Colors.white,
            size: 16,
          ),
          label: Text(
            st.isActive
                ? 'Active Trip'
                : st.isPaused
                ? 'Paused Trip'
                : 'No Active Trip',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: color,
        ),
        const SizedBox(width: 8),
        Text('Last ping: $age'),
      ],
    );
  }

  String _ageStr(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    return '${d.inMinutes}m ago';
  }
}

// ===== HOS Snapshot =====
class _HosState {
  final String dutyStatus; // Driving / On-duty / Off-duty / Sleeper
  final int drivingRemainingMin;
  final int shiftRemainingMin;
  final int cycleRemainingMin;
  final DateTime lastLogTs;
  final bool offline;
  const _HosState({
    required this.dutyStatus,
    required this.drivingRemainingMin,
    required this.shiftRemainingMin,
    required this.cycleRemainingMin,
    required this.lastLogTs,
    this.offline = false,
  });
  _HosState copyWith({
    String? dutyStatus,
    int? drivingRemainingMin,
    int? shiftRemainingMin,
    int? cycleRemainingMin,
    DateTime? lastLogTs,
    bool? offline,
  }) => _HosState(
    dutyStatus: dutyStatus ?? this.dutyStatus,
    drivingRemainingMin: drivingRemainingMin ?? this.drivingRemainingMin,
    shiftRemainingMin: shiftRemainingMin ?? this.shiftRemainingMin,
    cycleRemainingMin: cycleRemainingMin ?? this.cycleRemainingMin,
    lastLogTs: lastLogTs ?? this.lastLogTs,
    offline: offline ?? this.offline,
  );
}

final _hosProvider = StateNotifierProvider<_HosController, _HosState>(
  (ref) => _HosController(),
);

class _HosController extends StateNotifier<_HosState> {
  void setDutyStatus(String status) {
    state = state.copyWith(dutyStatus: status, lastLogTs: DateTime.now());
  }

  _HosController()
    : super(
        _HosState(
          dutyStatus: 'Off-duty',
          drivingRemainingMin: 480,
          shiftRemainingMin: 600,
          cycleRemainingMin: 4320,
          lastLogTs: DateTime.now(),
        ),
      );
  Timer? _timer;
  void startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => tick());
  }

  void tick() {
    if (state.offline) return;
    // decrement 1 minute if Driving
    if (state.dutyStatus == 'Driving') {
      state = state.copyWith(
        drivingRemainingMin: (state.drivingRemainingMin - 1).clamp(0, 100000),
        shiftRemainingMin: (state.shiftRemainingMin - 1).clamp(0, 100000),
        cycleRemainingMin: (state.cycleRemainingMin - 1).clamp(0, 100000),
        lastLogTs: DateTime.now(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _HosControlsEmbed extends StatelessWidget {
  const _HosControlsEmbed();
  @override
  Widget build(BuildContext context) {
    return const HosControls();
  }
}

class _HosSnapshotCard extends ConsumerStatefulWidget {
  const _HosSnapshotCard();
  @override
  ConsumerState<_HosSnapshotCard> createState() => _HosSnapshotCardState();
}

class _HosSnapshotCardState extends ConsumerState<_HosSnapshotCard> {
  Future<void> _writeHosStatus(String status) async {
    // ignore: avoid_print
    print('[click] HOS: Set status $status');
    // Update local snapshot immediately
    ref.read(_hosProvider.notifier).setDutyStatus(status);
    // Persist to Supabase if configured
    try {
      final cfg = ref.read(appConfigProvider);
      final ready =
          cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
      if (!ready) return;
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.functions.invoke(
        'hos_ingest',
        body: {
          'driver_user_id': user.id,
          'status': status.toLowerCase(),
          'start_time': DateTime.now().toUtc().toIso8601String(),
          'source': 'manual',
        },
      );
    } catch (_) {}
  }

  Future<void> _openHosDetails(BuildContext context) async {
    // Fetch recent logs (if possible) and show status actions
    List<Map<String, dynamic>> logs = const [];
    try {
      final cfg = ref.read(appConfigProvider);
      final ready =
          cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
      final user = Supabase.instance.client.auth.currentUser;
      if (ready && user != null) {
        final rows = await Supabase.instance.client
            .from('hos_logs')
            .select('status, start_time')
            .eq('driver_user_id', user.id)
            .order('start_time', ascending: false)
            .limit(10);
        logs = (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final hos = ref.read(_hosProvider);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HOS Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('Status: ${hos.dutyStatus}')),
                  Chip(
                    label: Text('Driving: ${_fmtMin(hos.drivingRemainingMin)}'),
                  ),
                  Chip(label: Text('Shift: ${_fmtMin(hos.shiftRemainingMin)}')),
                  Chip(label: Text('Cycle: ${_fmtMin(hos.cycleRemainingMin)}')),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Change status:'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await _writeHosStatus('Driving');
                    },
                    child: const Text('Driving'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await _writeHosStatus('On-duty');
                    },
                    child: const Text('On-duty'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await _writeHosStatus('Off-duty');
                    },
                    child: const Text('Off-duty'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await _writeHosStatus('Sleeper');
                    },
                    child: const Text('Sleeper'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (logs.isNotEmpty) const Text('Recent logs:'),
              if (logs.isNotEmpty) const SizedBox(height: 6),
              if (logs.isNotEmpty)
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (c, i) {
                      final r = logs[i];
                      final when = DateTime.tryParse(
                        r['logged_at'] as String? ?? '',
                      )?.toLocal();
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.event_note),
                        title: Text(r['duty_status'] as String? ?? ''),
                        subtitle: Text(when != null ? TimeFmt.relative(when) : ''),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    ref.read(_hosProvider.notifier).startTicking();
  }

  @override
  Widget build(BuildContext context) {
    final hos = ref.watch(_hosProvider);
    final stale = DateTime.now().difference(hos.lastLogTs).inMinutes > 15;
    Color chipColor;
    if (hos.drivingRemainingMin > 120) {
      chipColor = Colors.green;
    } else if (hos.drivingRemainingMin >= 60) {
      chipColor = Colors.amber;
    } else {
      chipColor = Colors.red;
    }
    final alert = hos.drivingRemainingMin < 45;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timelapse),
                const SizedBox(width: 8),
                const Text(
                  'HOS Snapshot',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (stale)
                  const Chip(
                    label: Text('Stale'),
                    backgroundColor: Colors.orangeAccent,
                  ),
              ],
            ),
            if (alert) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Consider a break soon.'),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Status: ${hos.dutyStatus}')),
                Chip(
                  label: Text('Driving: ${_fmtMin(hos.drivingRemainingMin)}'),
                  backgroundColor: chipColor.withValues(alpha: 0.15),
                ),
                Chip(label: Text('Shift: ${_fmtMin(hos.shiftRemainingMin)}')),
                Chip(label: Text('Cycle: ${_fmtMin(hos.cycleRemainingMin)}')),
                if (hos.offline)
                  const Chip(label: Text('Offline — HOS paused')),
                // Proactive break planning: show legal-by countdown
                Builder(builder: (_) {
                  final legalBy = DateTime.now().add(Duration(minutes: hos.drivingRemainingMin));
                  return Chip(label: Text('Legal by: ${TimeFmt.hm(legalBy)}'));
                }),
              ],
            ),
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await _showBreakSuggestions(context, ref);
                  },
                  icon: const Icon(Icons.local_hotel),
                  label: const Text('Find rest areas'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _openHosDetails(context),
                child: const Text('Open HOS Logs'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtMin(int m) {
    final h = m ~/ 60;
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$h:${mm}h';
  }
}

class _TripControlsCard extends ConsumerWidget {
  const _TripControlsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(activeTripControllerProvider);
    final actions = ref.read(activeTripControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.directions_run),
                SizedBox(width: 8),
                Text(
                  'Trip Controls',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: (st.isActive || st.isPaused)
                      ? null
                      : () async {
                          final hos = ref.read(_hosProvider);
                          if (hos.drivingRemainingMin <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No legal driving time remaining.',
                                ),
                              ),
                            );
                            return;
                          }
                          // If hazmat preselected, require confirmation at trip start
                          final stPlan = ref.read(_plannerProvider);
                          if (stPlan.hazmat) {
                            final ok =
                                await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Confirm Hazmat'),
                                    content: const Text(
                                      'Hazmat routing will be applied. Proceed?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Proceed'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (!ok) return;
                          }
                          app_log.AppLogger.info('[click] TripControls: Start');
                          actions.start();
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                OutlinedButton.icon(
                  onPressed: st.isActive
                      ? () {
                          app_log.AppLogger.info('[click] TripControls: Pause');
                          actions.pause();
                        }
                      : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                OutlinedButton.icon(
                  onPressed: st.isPaused
                      ? () {
                          app_log.AppLogger.info('[click] TripControls: Resume');
                          actions.resume();
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
                OutlinedButton.icon(
                  onPressed: (st.isActive || st.isPaused)
                      ? () {
                          // ignore: avoid_print
                          app_log.AppLogger.info('[click] TripControls: End');
                          actions.end();
                        }
                      : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('End'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    app_log.AppLogger.info('[click] Map: Follow me');
                    _followMe(context, ref);
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('Follow me'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    app_log.AppLogger.info('[click] Map: Recenter');
                    _recenter(context);
                  },
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Recenter'),
                ),
                OutlinedButton.icon(
                  onPressed: (st.tripId != null && !st.isActive && !st.isPaused)
                      ? () {
                          app_log.AppLogger.info('[click] TripControls: Resume last');
                          actions.resumeLast();
                        }
                      : null,
                  icon: const Icon(Icons.replay),
                  label: const Text('Resume last'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _followMe(BuildContext context, WidgetRef ref) async {
    // Try to write a heartbeat position for the current truck to ensure trail updates
    try {
      final active = ref.read(activeTripControllerProvider);
      if (active.truckId != null) {
        final telem = ref.read(telemetryServiceProvider);
        // As we don't have device GPS here, just duplicate last known position timestamp to trigger UI streams
        final positions = await telem.listCurrentPositions();
        final p = positions.firstWhere(
          (e) => e.truckId == active.truckId,
          orElse: () =>
              positions.firstOrNull ??
              TruckPosition(
                truckId: active.truckId!,
                lat: 39.5,
                lng: -98.35,
                gpsTs: DateTime.now().toUtc(),
                health: 'idle',
              ),
        );
        await telem.ingestPosition(
          truckId: active.truckId!,
          lat: p.lat,
          lng: p.lng,
          speedKph: p.speedKph,
          headingDeg: p.headingDeg,
          gpsTs: DateTime.now().toUtc(),
          source: 'app_follow_me',
          tripId: active.tripId,
        );
      }
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Follow me enabled (map will recenter on movement)'),
      ),
    );
  }

  void _recenter(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Map recentered to current position')),
    );
  }
}

class _HealthFooter extends ConsumerWidget {
  const _HealthFooter();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Simple indicators: API configured, documents queue length
    final cfg = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(appConfigProvider);
    final supaReady =
        cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
    final docs = ref.watch(documentsProvider);
    final queued = docs
        .where(
          (d) =>
              d.status == UploadStatus.queued ||
              d.status == UploadStatus.failed,
        )
        .length;
    final color = supaReady ? Colors.green : Colors.red;
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(supaReady ? 'Online' : 'Offline'),
        const SizedBox(width: 12),
        ActionChip(
          label: Text('Docs queue: $queued'),
          onPressed: () => context.push('/documents'),
        ),
      ],
    );
  }
}

class _FreeTierAdsBanner extends StatelessWidget {
  const _FreeTierAdsBanner();
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade50,
      child: ListTile(
        leading: const Icon(Icons.campaign),
        title: const Text('Sponsored: Truck Stop Deals'),
        subtitle: const Text(
          'Great fuel prices and showers ahead. Upgrade to hide ads.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening sponsor page...')),
        ),
      ),
    );
  }
}

class _TripHistoryCard extends ConsumerWidget {
  const _TripHistoryCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(_endedTripsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip History (this session)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (trips.isEmpty) const Text('No completed trips yet.'),
            for (final t in trips)
              ListTile(
                leading: const Icon(Icons.trip_origin),
                title: Text(t.tripId),
                subtitle: Text('${t.startedAt} → ${t.endedAt}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(approachAlertsProvider);
    if (alerts.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text('Notifications'),
          subtitle: Text('No alerts yet for this trip.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final a in alerts)
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: Text(
                  'Weigh station ${a.status == WeighStatus.open ? 'OPEN' : 'UNKNOWN'}',
                ),
                subtitle: Text(
                  'ETA ~${a.eta.difference(DateTime.now().toUtc()).inMinutes.clamp(0, 999)} min',
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: const Text('Clear Trip'),
                onPressed: () =>
                    ref.read(approachAlertsProvider.notifier).clearTrip(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeighStationBanner extends ConsumerWidget {
  static String _miOrMin(int etaMin) => '~$etaMin min';
  static String _ago(DateTime t) {
    final diff = DateTime.now().toUtc().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }

  const _WeighStationBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlitz = ref.watch(isBlitzDayProvider);
    final alerts = ref.watch(approachAlertsProvider);
    final stations = ref.watch(weighStationsProvider);
    final quiet = ref.watch(_quietModeProvider);

    if (alerts.isEmpty || quiet) {
      // Show Blitz banner low-priority when active
      if (isBlitz) {
        return Card(
          color: Colors.amber.shade50,
          child: const ListTile(
            leading: Icon(Icons.report, color: Colors.amber),
            title: Text('Inspection Blitz Week'),
            subtitle: Text(
              'Extra inspections likely. Keep logs and equipment in top shape.',
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final a = alerts.first; // show only next
    final stationMatch = stations.isNotEmpty
        ? stations.firstWhere((s) => s.id == a.stationId, orElse: () => stations.first)
        : null;
    final etaMin = a.eta
        .difference(DateTime.now().toUtc())
        .inMinutes
        .clamp(0, 999);
    final actions = ref.read(weighStationsActionsProvider);
    final trust = a.source == 'official'
        ? 'Official'
        : (a.confidence >= 0.6 ? 'Crowd' : 'Low confidence');
    if (etaMin <= 3 && !a.acknowledged) {
      // soft toast
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scale within 3 minutes ahead'),
              duration: Duration(seconds: 2),
            ),
          );
          ref.read(weighStationsActionsProvider).acknowledge(a.stationId);
        }
      });
    }
    return Card(
      color: Colors.red.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.monitor_weight, color: Colors.red),
            title: Text(
              'Scale ahead (${a.status == WeighStatus.open
                  ? 'OPEN'
                  : a.status == WeighStatus.closed
                  ? 'CLOSED'
                  : 'UNKNOWN'}) • ${_miOrMin(etaMin)}',
            ),
            subtitle: Text(
              stationMatch == null
                  ? 'Unknown location • ${_ago(a.eta)}'
                  : '${stationMatch.name} • ${stationMatch.highway} ${stationMatch.direction} • ${_ago(a.eta)}',
            ),
            trailing: Chip(label: Text(trust)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => actions.acknowledge(a.stationId),
                  icon: const Icon(Icons.check),
                  label: const Text('Acknowledge'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      actions.snooze(a.stationId, const Duration(hours: 1)),
                  icon: const Icon(Icons.snooze),
                  label: const Text('Snooze 1h'),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.map),
                  label: const Text('View on Map'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () =>
                      actions.report(a.stationId, WeighStatus.open),
                  icon: const Icon(Icons.monitor_weight),
                  label: const Text('Report OPEN'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      actions.report(a.stationId, WeighStatus.closed),
                  icon: const Icon(Icons.monitor_weight_outlined),
                  label: const Text('Report CLOSED'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotInspectionSheet extends StatefulWidget {
  final bool preTrip;
  const _DotInspectionSheet({required this.preTrip});
  @override
  State<_DotInspectionSheet> createState() => _DotInspectionSheetState();
}

class _DotInspectionSheetState extends State<_DotInspectionSheet> {
  final Map<String, bool> _items = {
    'Lights & Reflectors': false,
    'Brakes': false,
    'Tires': false,
    'Coupling Devices': false,
    'Emergency Equipment': false,
  };
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final defects = _items.entries
          .where((e) => e.value == false)
          .map((e) => {'name': e.key, 'ok': false})
          .toList();
      final driverId = Supabase.instance.client.auth.currentUser?.id;
      if (driverId == null) throw Exception('Not signed in');
      await retry(
        () => Supabase.instance.client.functions
            .invoke(
              'inspection_submit',
              body: {
                'driver_user_id': driverId,
                'vehicle_id': 'unknown',
                'type': widget.preTrip ? 'pre_trip' : 'post_trip',
                'defects': defects,
                'certified_safe': defects.isEmpty,
              },
            )
            .timeout(const Duration(seconds: 10)),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.preTrip ? 'Pre-Trip Inspection' : 'Post-Trip Inspection',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mark each item OK. Unchecked items will be recorded as defects.',
          ),
          const SizedBox(height: 8),
          ..._items.keys.map(
            (k) => CheckboxListTile(
              value: _items[k],
              onChanged: (v) => setState(() => _items[k] = v ?? false),
              title: Text(k),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving…' : 'Submit Inspection'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTrainingCard extends StatelessWidget {
  const _HelpTrainingCard();
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Training',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            ListTile(
              leading: Icon(Icons.school_outlined),
              title: Text('How to avoid HOS violations'),
            ),
            ListTile(
              leading: Icon(Icons.local_gas_station_outlined),
              title: Text('How to log fuel'),
            ),
            ListTile(
              leading: Icon(Icons.checklist_rtl),
              title: Text('Pre-trip inspection guide'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportTicketsCard extends StatelessWidget {
  const _SupportTicketsCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.support_agent),
        title: const Text('Support Tickets'),
        subtitle: const Text('View and create tickets (driver scoped)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support center coming soon')),
        ),
      ),
    );
  }
}

class _FuelSpendMyLogsCard extends StatefulWidget {
  const _FuelSpendMyLogsCard();
  @override
  State<_FuelSpendMyLogsCard> createState() => _FuelSpendMyLogsCardState();
}

class _FuelSpendMyLogsCardState extends State<_FuelSpendMyLogsCard> {
  final _galCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  List<String> _history = const [];
  @override
  void dispose() {
    _galCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final gal = double.tryParse(_galCtrl.text.trim()) ?? 0;
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (gal <= 0 || amt <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter gallons and amount')));
      return;
    }
    setState(() {
      _history = [
        '${gal.toStringAsFixed(1)} gal • \$${amt.toStringAsFixed(2)}',
        ..._history,
      ].take(5).toList();
      _galCtrl.clear();
      _amtCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_gas_station_outlined),
                SizedBox(width: 8),
                Text(
                  'Fuel & Spend (My logs)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _galCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Gallons',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount USD',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_history.isEmpty) const Text('No logs yet.'),
            for (final h in _history)
              ListTile(leading: const Icon(Icons.receipt_long), title: Text(h)),
          ],
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ---- Trip Summary Calculation Helpers ----
Future<void> _recalculate(
  BuildContext context,
  WidgetRef ref,
  _PlanState st, {
  bool manual = false,
}) async {
  if (st.origin == null || st.destination == null) {
    // inline warning handled by UI; also toast if manually attempted
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add both points to calculate.')),
      );
    }
    return;
  }
  final notifier = ref.read(_plannerProvider.notifier);
  final before = DateTime.now();
  final newHash = _calcInputHash(st);
  if (newHash == st.inputHash) {
    if (manual) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already up to date.')));
    }
    return;
  }
  // Corridor TTL: avoid noisy recalcs within 2 minutes unless manual
  if (!manual && st.lastCalculatedAt != null && DateTime.now().difference(st.lastCalculatedAt!) < const Duration(minutes: 2)) {
    return;
  }
  notifier.state = st.copyWith(calculating: true);
  try {
    // Basic conflict example: if height unreasonable (>20 ft), block
    try {
      final prof = ref.read(driverVehicleProfileProvider);
      if ((prof.heightFt ?? 0) > 20) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot navigate—height restriction (check vehicle height).',
            ),
          ),
        );
        notifier.state = st.copyWith(calculating: false);
        return;
      }
    } catch (_) {}
    // Simulate routing call 1.2s
    await Future.delayed(const Duration(milliseconds: 1200));
    final distance =
        (st.hazmat ? 520.0 : 500.0) + (st.avoidTolls ? -10.0 : 0.0);
    final baseHours =
        9.0 + (st.hazmat ? 0.3 : 0.0) + (st.trafficOn ? 0.2 : 0.0);
    var etaDur = Duration(minutes: (baseHours * 60).round());
    final calcMs = DateTime.now().difference(before).inMilliseconds;

    // HOS-aware ETA adjustment (RPC: hos_remaining_drive_minutes)
    bool adjustedForHos = false;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final dynamic hosRes = await Supabase.instance.client
            .rpc('hos_remaining_drive_minutes', params: {
          'p_driver_user_id': uid,
          'p_at': DateTime.now().toUtc().toIso8601String(),
        });
        // Expecting a SETOF with fields remaining_minutes, adjusted_for_hos
        int? remaining;
        if (hosRes is List && hosRes.isNotEmpty) {
          final row = hosRes.first as Map;
          remaining = (row['remaining_minutes'] as num?)?.toInt();
        } else if (hosRes is Map) {
          remaining = (hosRes['remaining_minutes'] as num?)?.toInt();
        }
        if (remaining != null && remaining < etaDur.inMinutes) {
          // Add a 10h break (simplified) after remaining minutes are consumed
          etaDur = Duration(minutes: remaining + 600);
          adjustedForHos = true;
        }
      }
    } catch (_) {
      // Ignore HOS errors in MVP
    }

    final updated = st.copyWith(
      distanceMiles: distance,
      eta: etaDur,
      calculating: false,
      lastCalculatedAt: DateTime.now(),
      lastTrafficUpdatedAt: st.trafficOn
          ? DateTime.now()
          : st.lastTrafficUpdatedAt,
      inputHash: newHash,
      routeVersion: st.routeVersion + 1,
    );
    notifier.state = updated;

    // Proactive break planning: suggest rest areas when HOS adjustment applied
    if (adjustedForHos && context.mounted) {
      // fire-and-forget; UI sheet will present suggestions
      // ignore: unawaited_futures
      _showBreakSuggestions(context, ref);
    }

    await _persistTripCalcLatest(ref, updated, calcMs: calcMs, adjustedForHos: adjustedForHos);
    await _persistTripSummary(
      ref,
      updated,
    ); // persist summary so the function isn't unused

    // MVP: Route compliance cross-check (RoadDogg reference layers)
    try {
      // 1) Weigh/inspection stations: reuse approachAlertsProvider within 15-minute window
      // Use a generic corridor center if live GPS not available (NJ centroid as example)
      ref.read(approachAlertsProvider.notifier).clearTrip();
      ref
          .read(approachAlertsProvider.notifier)
          .evaluateApproach(
            currLat: 40.0583,
            currLng: -74.4057,
            avgSpeedMph: 55,
          );
      final weighAlerts = ref.read(approachAlertsProvider);

      // 2) Simple restricted route/hazmat stubs (real app: RoadDogg API compare)
      final List<String> warnings = [];
      if (st.hazmat) {
        warnings.add(
          'Hazmat compliance applied — verify placards/segregation.',
        );
      }
      // Add state-based hints from restrictions service (asset-backed)
      try {
        final hints = await RestrictionsService.instance.hintsFor(
          origin: st.origin,
          destination: st.destination,
          hazmat: st.hazmat,
        );
        warnings.addAll(hints);
      } catch (_) {}
      if (weighAlerts.isNotEmpty) {
        warnings.add('Weigh/Inspection station ahead within ~15 minutes.');
      }

      if (warnings.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Compliance check: ${warnings.join(' • ')}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Compliance check: No issues detected on planned route (MVP).',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      /* ignore cross-check errors in MVP */
    }
  } catch (e) {
    notifier.state = st.copyWith(calculating: false);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't calculate route. Check connection or try again.",
        ),
      ),
    );
  }
}

String _calcInputHash(_PlanState st) {
  final s =
      '${st.origin}|${st.destination}|${st.hazmat}|${st.avoidTolls}|${st.trafficOn}';
  int h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h.toRadixString(16);
}

Future<void> _persistTripCalcLatest(
  dynamic ref,
  _PlanState st, {
  required int calcMs,
  bool adjustedForHos = false,
}) async {
  try {
    final c = Supabase.instance.client;
    final active = ref.read(activeTripControllerProvider);
    final now = DateTime.now();
    final etaSeconds = st.eta?.inSeconds;
    final etaP50 = etaSeconds; // baseline
    final etaP90 = etaSeconds != null ? (etaSeconds * 1.10).round() : null; // simple +10% band
    final details = {
      'kind': 'latest',
      'trip_id': active.tripId,
      'truck_id': active.truckId,
      'distance_miles': st.distanceMiles,
      'eta_utc': now.add(st.eta ?? const Duration()).toUtc().toIso8601String(),
      'eta_local_tz': now.timeZoneName,
      'travel_time_seconds': etaSeconds,
      'eta_p50_seconds': etaP50,
      'eta_p90_seconds': etaP90,
      'adjusted_for_hos': adjustedForHos,
      'tolls_flag': !st.avoidTolls,
      'tolls_estimated_cents': st.avoidTolls ? 0 : 2500,
      'hazmat_applied': st.hazmat,
      'fuel_estimated_gallons': (st.distanceMiles ?? 0) / 6.5,
      'fuel_estimated_cost_cents': (((st.distanceMiles ?? 0) / 6.5) * 3.8 * 100)
          .round(),
      'ppm_estimate': null,
      'routing_provider': 'mock_router',
      'route_version': st.routeVersion,
      'options_snapshot': {
        'hazmat': st.hazmat,
        'avoid_tolls': st.avoidTolls,
        'traffic_on': st.trafficOn,
        'truck_profile': {'mpg': 6.5, 'weight_kg': null},
      },
      'polyline_len': 100,
      'last_calculated_at': DateTime.now().toUtc().toIso8601String(),
      'input_hash': st.inputHash,
      'compute_status': 'success',
      'error_note': null,
      'calc_time_ms': calcMs,
      'routing_status_code': 200,
    };
    await c.from('dispatch_events').insert({
      'event_type': 'trip_calc_latest',
      'details': details,
    });

    // Route lifecycle event
    await c.from('dispatch_events').insert({
      'event_type': 'route_lifecycle',
      'details': {
        'trip_id': active.tripId,
        'stage': adjustedForHos ? 'adjusted_for_hos' : 'planned',
        'delta_seconds': adjustedForHos && etaP90 != null && etaP50 != null ? (etaP90 - etaP50) : null,
        'calc_time_ms': calcMs,
        'route_version': st.routeVersion,
      },
    });
  } catch (e) {
    app_log.AppLogger.error('[dispatch_events] persist latest calc failed', e);
  }
}

Future<void> _persistTripCalcBaseline(dynamic ref, _PlanState st) async {
  if (st.distanceMiles == null || st.eta == null) return;
  try {
    final c = Supabase.instance.client;
    final active = ref.read(activeTripControllerProvider);
    final now = DateTime.now();
    final details = {
      'kind': 'baseline',
      'trip_id': active.tripId,
      'truck_id': active.truckId,
      'distance_miles': st.distanceMiles,
      'eta_utc': now.add(st.eta ?? const Duration()).toUtc().toIso8601String(),
      'eta_local_tz': now.timeZoneName,
      'travel_time_seconds': st.eta?.inSeconds,
      'tolls_flag': !st.avoidTolls,
      'tolls_estimated_cents': st.avoidTolls ? 0 : 2500,
      'hazmat_applied': st.hazmat,
      'fuel_estimated_gallons': (st.distanceMiles ?? 0) / 6.5,
      'fuel_estimated_cost_cents': (((st.distanceMiles ?? 0) / 6.5) * 3.8 * 100)
          .round(),
      'ppm_estimate': null,
      'routing_provider': 'mock_router',
      'route_version': st.routeVersion,
      'options_snapshot': {
        'hazmat': st.hazmat,
        'avoid_tolls': st.avoidTolls,
        'traffic_on': st.trafficOn,
        'truck_profile': {'mpg': 6.5, 'weight_kg': null},
      },
      'polyline_len': 100,
      'last_calculated_at': DateTime.now().toUtc().toIso8601String(),
      'input_hash': st.inputHash,
      'compute_status': 'success',
      'error_note': null,
    };
    await c.from('dispatch_events').insert({
      'event_type': 'trip_calc_baseline',
      'details': details,
    });
  } catch (e) {
    app_log.AppLogger.error('[dispatch_events] persist baseline failed', e);
  }
}

Future<void> _loadLatestCalc(dynamic ref) async {
  try {
    final c = Supabase.instance.client;
    final active = ref.read(activeTripControllerProvider);
    if (active.tripId == null) return;
    final List rows = await c
        .from('dispatch_events')
        .select('details, created_at')
        .eq('event_type', 'trip_calc_latest')
        .eq('details->>trip_id', active.tripId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isNotEmpty) {
      final det = Map<String, dynamic>.from(rows.first['details'] as Map);
      final st = ref.read(_plannerProvider);
      final distance = (det['distance_miles'] as num?)?.toDouble();
      final secs = det['travel_time_seconds'] as int?;
      final inputHash = det['input_hash'] as String?;
      final routeVersion = (det['route_version'] as int?) ?? st.routeVersion;
      ref.read(_plannerProvider.notifier).state = st.copyWith(
        distanceMiles: distance,
        eta: secs == null ? st.eta : Duration(seconds: secs),
        lastCalculatedAt:
            DateTime.tryParse(det['last_calculated_at'] as String? ?? '') ??
            st.lastCalculatedAt,
        inputHash: inputHash ?? st.inputHash,
        routeVersion: routeVersion,
      );
    }
  } catch (e) {
    app_log.AppLogger.error('[dispatch_events] load latest calc failed', e);
  }
}


// ---- Proactive Break Planning: parking_forecast integration ----
Future<void> _showBreakSuggestions(
  BuildContext context,
  WidgetRef ref, {
  int windowMin = 60,
  int limit = 6,
}) async {
  try {
    // Build best-effort waypoints from telemetry and/or origin/destination strings
    final waypoints = await _buildWaypoints(ref);

    // Fallback anchor when nothing could be resolved
    final fallback = const [
      {'lat': 39.5, 'lng': -98.35}
    ];

    final fn = await Supabase.instance.client.functions.invoke(
      'parking_forecast',
      body: {
        'waypoints': waypoints.isNotEmpty ? waypoints : fallback,
        'window_minutes': windowMin,
        'limit': limit,
      },
    );

    final data = fn.data;
    final List<dynamic> stops = (data is Map && data['stops'] is List)
        ? (data['stops'] as List)
        : (data is List ? data : const []);

    if (!context.mounted) return;

    if (stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rest areas found nearby.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_hotel),
                  SizedBox(width: 8),
                  Text('Suggested Rest Areas', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: stops.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = (stops[i] as Map).cast<String, dynamic>();
                    final name = (s['name'] ?? s['stop_id'] ?? 'Stop').toString();
                    final etaIso = s['eta']?.toString();
                    final eta = etaIso != null ? DateTime.tryParse(etaIso) : null;
                    final avail = s['availability_est'];
                    final conf = (s['confidence'] is num) ? (s['confidence'] as num).toDouble() : null;
                    final distMi = (s['distance_mi'] is num) ? (s['distance_mi'] as num).toDouble() : null;
                    return ListTile(
                      leading: const Icon(Icons.local_parking),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text([
                        if (eta != null) 'ETA ${TimeFmt.hm(eta)}',
                        if (avail != null) 'Avail ~$avail',
                        if (conf != null) 'Conf ${(conf * 100).toStringAsFixed(0)}%'
                      ].join(' • ')),
                      trailing: Text(distMi == null ? '' : '${distMi.toStringAsFixed(1)} mi'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Navigation coming soon')), // stub
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not fetch rest areas: $e')),
    );
  }
}


// ---- Waypoint builder: telemetry + origin/destination (best-effort) ----
Future<List<Map<String, double>>> _buildWaypoints(WidgetRef ref) async {
  final List<Map<String, double>> pts = [];

  double? parse(String? s) => double.tryParse((s ?? '').trim());

  bool validLatLng(double lat, double lng) => lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  double haversineMi(double lat1, double lon1, double lat2, double lon2) {
    const R = 3958.8; // miles
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180.0;
    final dLon = (lon2 - lon1) * 3.141592653589793 / 180.0;
    final la1 = lat1 * 3.141592653589793 / 180.0;
    final la2 = lat2 * 3.141592653589793 / 180.0;
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(la1) * cos(la2) * sin(dLon / 2) * sin(dLon / 2));
    return 2 * R * asin(sqrt(a));
  }

  bool nearExisting(double lat, double lng, {double withinMeters = 100}) {
    for (final p in pts) {
      final dMi = haversineMi(lat, lng, p['lat']!, p['lng']!);
      if (dMi * 1609.34 < withinMeters) return true;
    }
    return false;
  }

  void add(double lat, double lng) {
    if (validLatLng(lat, lng) && !nearExisting(lat, lng)) {
      pts.add({'lat': lat, 'lng': lng});
    }
  }

  // 1) Telemetry current position (first available)
  try {
    final telemetry = ref.read(telemetryServiceProvider);
    final positions = await telemetry.listCurrentPositions();
    if (positions.isNotEmpty) {
      add(positions.first.lat, positions.first.lng);
    }
  } catch (_) {}

  // 2) Origin/destination strings: accept "lat,lng" numeric form only (best-effort)
  try {
    final st = ref.read(_plannerProvider);
    for (final s in [st.origin, st.destination]) {
      if (s == null) continue;
      final parts = s.split(',');
      if (parts.length != 2) continue;
      final lat = parse(parts[0]);
      final lng = parse(parts[1]);
      if (lat != null && lng != null) {
        add(lat, lng);
      }
    }
  } catch (_) {}

  // Keep at most 3 points: current, origin, destination
  if (pts.length > 3) {
    return pts.take(3).toList();
  }
  return pts;
}
