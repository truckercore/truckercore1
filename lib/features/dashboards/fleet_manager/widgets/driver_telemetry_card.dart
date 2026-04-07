import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/telematics_service.dart';

class DriverTelemetryCard extends ConsumerWidget {
  final String driverUserId;
  const DriverTelemetryCard({super.key, required this.driverUserId});

  Color _colorForHarsh(int count) {
    if (count >= 10) return Colors.redAccent;
    if (count >= 4) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(telematicsServiceProvider);
    return FutureBuilder(
      future: Future.wait([
        svc.lastSpeedingEvent(driverUserId),
        svc.totalIdleMinutesToday(driverUserId),
        svc.harshEventsCount7d(driverUserId),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Card(
            child: SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final lastSpeeding = (snap.data as List)[0];
        final idleMin = (snap.data as List)[1] as int? ?? 0;
        final harshCnt = (snap.data as List)[2] as int? ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.directions_car, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver Telemetry',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.speed, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Last speeding: ${lastSpeeding == null ? '—' : (lastSpeeding as TelematicsEvent).occurredAt.toLocal()}',
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timelapse, size: 16),
                              const SizedBox(width: 4),
                              Text('Idle today: $idleMin min'),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _colorForHarsh(
                                harshCnt,
                              ).withValues(alpha: 0.12),
                              border: Border.all(
                                color: _colorForHarsh(harshCnt),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber, size: 16),
                                const SizedBox(width: 4),
                                Text('Harsh 7d: $harshCnt'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Open Driver Details',
                  onPressed: () {
                    // navigate to driver details if route exists
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pushNamed('/drivers/$driverUserId');
                  },
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
