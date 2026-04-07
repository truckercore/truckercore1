import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../common/widgets/section_header.dart';
import '../../compliance/alerts_controller.dart';
import '../../routes/data/trip_route_repository.dart';
import '../compliance_alerts_service.dart';

class ComplianceAlertsPanel extends ConsumerStatefulWidget {
  final String title;
  final List<LatLng>? route; // optional; if null, uses tripRouteStreamProvider

  const ComplianceAlertsPanel({
    super.key,
    this.title = 'Compliance Alerts',
    this.route,
  });

  @override
  ConsumerState<ComplianceAlertsPanel> createState() =>
      _ComplianceAlertsPanelState();
}

class _ComplianceAlertsPanelState extends ConsumerState<ComplianceAlertsPanel>
    with WidgetsBindingObserver {
  List<LatLng> _route = const [];
  bool _active = true;
  ProviderSubscription<AsyncValue<List<LatLng>>>? _routeSub;

  void _start(List<LatLng> route) {
    if (route.isEmpty) return;
    ref.read(alertsControllerProvider.notifier).start(route: route);
  }

  void _stop() {
    // Avoid using ref in dispose or after unmount; this method should only
    // be called while the widget is mounted (e.g., during lifecycle toggles).
    ref.read(alertsControllerProvider.notifier).stop();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize route source
    if (widget.route != null) {
      _route = widget.route!;
      _start(_route);
    } else {
      // Subscribe to route changes
      // Use listenManual to subscribe safely outside build; store sub and cancel in dispose
      _routeSub = ref.listenManual<AsyncValue<List<LatLng>>>(
        tripRouteStreamProvider,
        (prev, next) {
          if (!mounted) return;
          next.whenData((poly) {
            if (!mounted) return;
            _route = poly;
            if (_active) {
              _stop();
              _start(_route);
            }
          });
        },
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nowActive =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (nowActive == _active) return;
    _active = nowActive;
    if (!mounted) return;
    if (_active && _route.isNotEmpty) {
      _start(_route);
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    // Mark inactive to prevent any queued callbacks from calling start/stop.
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
    // Cancel route subscription first to avoid receiving more updates.
    _routeSub?.close();
    // IMPORTANT: Do not use ref in dispose. Provider should handle its own
    // cleanup via autoDispose/onDispose if needed.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(alertsControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: widget.title,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: s.recent.isEmpty
                    ? null
                    : () => ref.read(alertsControllerProvider.notifier).clear(),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        if (s.recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.white70),
                SizedBox(width: 8),
                Text('No recent compliance alerts.'),
              ],
            ),
          )
        else
          Column(
            children: s.recent
                .map(
                  (a) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        a.type == ComplianceAlertType.weighStationOpen
                            ? Icons.local_police
                            : Icons.announcement,
                        color: switch (a.severity) {
                          ComplianceSeverity.critical => const Color(
                            0xFFFF6B6B,
                          ),
                          ComplianceSeverity.warning => const Color(0xFFFFB020),
                          ComplianceSeverity.info => Theme.of(
                            context,
                          ).colorScheme.tertiary,
                        },
                      ),
                      title: Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        a.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: navigate to alert details
                      },
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
