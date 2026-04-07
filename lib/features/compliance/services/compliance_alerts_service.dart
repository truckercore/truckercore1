import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

enum ComplianceAudience { driver, ownerOperator, fleetManager, all }

enum ComplianceAlertType { weighStationOpen, inspectionWeek, advisory }

enum ComplianceSeverity { info, warning, critical }

class ComplianceAlert {
  final String id;
  final ComplianceAlertType type;
  final ComplianceSeverity severity;
  final ComplianceAudience audience;
  final String title;
  final String message;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String? stationId;
  final String? region;
  const ComplianceAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.audience,
    required this.title,
    required this.message,
    required this.effectiveFrom,
    this.effectiveTo,
    this.stationId,
    this.region,
  });
  bool get isActiveNow {
    final now = DateTime.now().toUtc();
    if (effectiveFrom.isAfter(now)) return false;
    if (effectiveTo != null && effectiveTo!.isBefore(now)) return false;
    return true;
  }
}

class Station {
  final String id;
  final String name;
  final LatLng position;
  final bool open;
  const Station({
    required this.id,
    required this.name,
    required this.position,
    required this.open,
  });
}

class ComplianceAlertsService {
  ComplianceAlertsService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    return (cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty)
        ? Supabase.instance.client
        : null;
  }

  final Distance _distance = const Distance();

  Stream<ComplianceAlert> routeAwareAlerts({
    required ComplianceAudience audience,
    required List<LatLng> route,
    double radiusMiles = 5.0,
  }) {
    final supa = _maybe();
    final controller = StreamController<ComplianceAlert>.broadcast();

    bool nearRoute(LatLng p, List<LatLng> line, double miles) {
      if (line.isEmpty) return false;
      final maxM = miles * 1609.344;
      for (var i = 0; i < line.length; i++) {
        if (_distance(line[i], p) <= maxM) return true;
        if (i < line.length - 1) {
          final mid = LatLng(
            (line[i].latitude + line[i + 1].latitude) / 2,
            (line[i].longitude + line[i + 1].longitude) / 2,
          );
          if (_distance(mid, p) <= maxM) return true;
        }
      }
      return false;
    }

    void emitStation(Station s) {
      controller.add(
        ComplianceAlert(
          id: 'station_${s.id}_${DateTime.now().millisecondsSinceEpoch}',
          type: ComplianceAlertType.weighStationOpen,
          severity: ComplianceSeverity.warning,
          audience: ComplianceAudience.all,
          title: 'Weigh/Inspection Station Open',
          message:
              '${s.name} is open ahead. Ensure HOS/ELD and docs are ready.',
          effectiveFrom: DateTime.now().toUtc(),
          stationId: s.id,
        ),
      );
    }

    Future<void> emitActiveInspectionWeek() async {
      final now = DateTime.now().toUtc();
      final supa = _maybe();
      if (supa != null) {
        try {
          final rows = await supa
              .from('compliance_alerts')
              .select()
              .eq('type', 'inspectionWeek')
              .eq('is_active', true)
              .lte('effective_from', now.toIso8601String())
              .or(
                'effective_to.is.null,effective_to.gte.${now.toIso8601String()}',
              )
              .limit(3);
          for (final r in (rows as List)) {
            controller.add(
              ComplianceAlert(
                id: r['id'] as String,
                type: ComplianceAlertType.inspectionWeek,
                severity: _mapSeverity(r['severity'] as String?),
                audience: _mapAudience(r['audience'] as String?),
                title: (r['title'] as String?) ?? 'Inspection Initiative',
                message:
                    (r['message'] as String?) ??
                    'Inspection week active. Expect increased inspections.',
                effectiveFrom:
                    (DateTime.tryParse(r['effective_from']?.toString() ?? '') ??
                            DateTime.now())
                        .toUtc(),
                effectiveTo: r['effective_to'] == null
                    ? null
                    : DateTime.tryParse(
                        r['effective_to']?.toString() ?? '',
                      )?.toUtc(),
                region: r['region'] as String?,
              ),
            );
          }
        } catch (_) {}
      } else {
        if (now.weekday == DateTime.monday) {
          controller.add(
            ComplianceAlert(
              id: 'mock_inspection_${now.millisecondsSinceEpoch}',
              type: ComplianceAlertType.inspectionWeek,
              severity: ComplianceSeverity.info,
              audience: audience,
              title: 'CVSA Inspection Week',
              message:
                  'Increased inspections expected. Verify pre-trip inspections and logs.',
              effectiveFrom: now,
              effectiveTo: now.add(const Duration(days: 7)),
            ),
          );
        }
      }
    }

    RealtimeChannel? channel;

    Future<void> attach() async {
      await emitActiveInspectionWeek();

      if (supa != null) {
        channel = supa.channel('public:stations');
        channel!
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'stations',
              callback: (payload) {
                final r = payload.newRecord;
                final s = Station(
                  id: '${r['id']}',
                  name: (r['name'] as String?) ?? 'Station',
                  position: LatLng(
                    (r['lat'] as num).toDouble(),
                    (r['lng'] as num).toDouble(),
                  ),
                  open: (r['open'] as bool?) ?? false,
                );
                if (s.open && nearRoute(s.position, route, radiusMiles)) {
                  emitStation(s);
                }
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'stations',
              callback: (payload) {
                final r = payload.newRecord;
                final s = Station(
                  id: '${r['id']}',
                  name: (r['name'] as String?) ?? 'Station',
                  position: LatLng(
                    (r['lat'] as num).toDouble(),
                    (r['lng'] as num).toDouble(),
                  ),
                  open: (r['open'] as bool?) ?? false,
                );
                if (s.open && nearRoute(s.position, route, radiusMiles)) {
                  emitStation(s);
                }
              },
            )
            .subscribe();

        try {
          final rows = await supa
              .from('stations')
              .select('id,name,lat,lng,open')
              .eq('open', true)
              .limit(200);
          for (final r in (rows as List)) {
            final s = Station(
              id: '${r['id']}',
              name: (r['name'] as String?) ?? 'Station',
              position: LatLng(
                (r['lat'] as num).toDouble(),
                (r['lng'] as num).toDouble(),
              ),
              open: (r['open'] as bool?) ?? false,
            );
            if (s.open && nearRoute(s.position, route, radiusMiles)) {
              emitStation(s);
            }
          }
        } catch (_) {}
      } else {
        Timer.periodic(const Duration(minutes: 5), (_) {
          if (route.isEmpty) return;
          controller.add(
            ComplianceAlert(
              id: 'mock_station_${DateTime.now().millisecondsSinceEpoch}',
              type: ComplianceAlertType.weighStationOpen,
              severity: ComplianceSeverity.warning,
              audience: ComplianceAudience.all,
              title: 'Weigh Station Possibly Open',
              message:
                  'A station near your route appears open. Ensure logs and docs are ready.',
              effectiveFrom: DateTime.now().toUtc(),
              stationId: 'mock',
            ),
          );
        });
      }
    }

    attach();
    controller.onCancel = () async {
      await channel?.unsubscribe();
      if (supa != null && channel != null) {
        supa.removeChannel(channel!);
      }
      await controller.close();
    };
    return controller.stream;
  }

  Future<void> sendInspectionWeekAlert({
    required DateTime fromUtc,
    required DateTime toUtc,
    String title = 'Inspection Week Active',
    String message =
        'Increased inspections expected. Ensure HOS/ELD and safety docs are up-to-date.',
    ComplianceSeverity severity = ComplianceSeverity.info,
    ComplianceAudience audience = ComplianceAudience.all,
    String? region,
  }) async {
    final supa = _maybe();
    if (supa == null) {
      throw Exception('Supabase not configured');
    }
    await supa.from('compliance_alerts').insert({
      'type': 'inspectionWeek',
      'title': title,
      'message': message,
      'severity': _severityStr(severity),
      'audience': _audienceStr(audience),
      'effective_from': fromUtc.toIso8601String(),
      'effective_to': toUtc.toIso8601String(),
      'region': region,
      'is_active': true,
    });
  }

  ComplianceSeverity _mapSeverity(String? v) {
    switch ((v ?? 'info').toLowerCase()) {
      case 'warning':
        return ComplianceSeverity.warning;
      case 'critical':
        return ComplianceSeverity.critical;
      default:
        return ComplianceSeverity.info;
    }
  }

  String _severityStr(ComplianceSeverity s) {
    switch (s) {
      case ComplianceSeverity.info:
        return 'info';
      case ComplianceSeverity.warning:
        return 'warning';
      case ComplianceSeverity.critical:
        return 'critical';
    }
  }

  ComplianceAudience _mapAudience(String? v) {
    switch ((v ?? 'all').toLowerCase()) {
      case 'driver':
        return ComplianceAudience.driver;
      case 'owneroperator':
      case 'owner_operator':
      case 'owner-operator':
        return ComplianceAudience.ownerOperator;
      case 'fleetmanager':
      case 'fleet_manager':
      case 'fleet-manager':
        return ComplianceAudience.fleetManager;
      default:
        return ComplianceAudience.all;
    }
  }

  String _audienceStr(ComplianceAudience a) {
    switch (a) {
      case ComplianceAudience.driver:
        return 'driver';
      case ComplianceAudience.ownerOperator:
        return 'ownerOperator';
      case ComplianceAudience.fleetManager:
        return 'fleetManager';
      case ComplianceAudience.all:
        return 'all';
    }
  }
}

final complianceAlertsServiceProvider = Provider<ComplianceAlertsService>(
  (ref) => ComplianceAlertsService(ref),
);
