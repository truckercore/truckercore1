import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './compliance_alerts_service.dart';

// Holds a rolling buffer of recent alerts for reuse across screens
class AlertsState {
  final List<ComplianceAlert> recent; // newest first
  const AlertsState(this.recent);
}

class AlertsController extends StateNotifier<AlertsState> {
  AlertsController(this.ref) : super(const AlertsState([])) {
    _restore();
  }
  final Ref ref;

  StreamSubscription<ComplianceAlert>? _sub;

  static const _prefsKey = 'recent_compliance_alerts_v1';
  static const _maxItemsDefault = 10;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => _fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = AlertsState(list);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.recent.map(_toJson).toList();
      await prefs.setString(_prefsKey, jsonEncode(jsonList));
    } catch (_) {
      // ignore
    }
  }

  void start({
    required List<LatLng> route,
    ComplianceAudience audience = ComplianceAudience.fleetManager,
    int maxItems = _maxItemsDefault,
  }) {
    _sub?.cancel();
    final service = ref.read(complianceAlertsServiceProvider);
    _sub = service
        .routeAwareAlerts(audience: audience, route: route, radiusMiles: 5)
        .listen((alert) async {
          final next = [alert, ...state.recent];
          state = AlertsState(next.take(maxItems).toList());
          await _persist();
        });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> clear() async {
    state = const AlertsState([]);
    await _persist();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // Minimal JSON adapters for persistence
  Map<String, dynamic> _toJson(ComplianceAlert a) => {
    'id': a.id,
    'type': a.type.name,
    'severity': a.severity.name,
    'title': a.title,
    'message': a.message,
    'createdAt': a.createdAt.toIso8601String(),
  };

  ComplianceAlert _fromJson(Map<String, dynamic> m) => ComplianceAlert(
    id: m['id'] as String,
    type: ComplianceAlertType.values.firstWhere(
      (t) => t.name == (m['type'] as String),
      orElse: () => ComplianceAlertType.general,
    ),
    severity: ComplianceSeverity.values.firstWhere(
      (s) => s.name == (m['severity'] as String),
      orElse: () => ComplianceSeverity.info,
    ),
    title: m['title'] as String,
    message: m['message'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}

final alertsControllerProvider =
    StateNotifierProvider<AlertsController, AlertsState>(
      (ref) => AlertsController(ref),
    );
