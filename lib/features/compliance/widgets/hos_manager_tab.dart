import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/widgets/error_card.dart';
import '../../../common/widgets/section_header.dart';
import '../../drivers/services/drivers_service.dart';
import '../hos_service.dart';

class HosManagerTab extends ConsumerStatefulWidget {
  const HosManagerTab({super.key});

  @override
  ConsumerState<HosManagerTab> createState() => _HosManagerTabState();
}

class _HosManagerTabState extends ConsumerState<HosManagerTab> {
  Driver? _selected;

  @override
  Widget build(BuildContext context) {
    final driversSvc = ref.watch(driversServiceProvider);
    final hosApi = ref.watch(hosApiProvider);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'HOS Compliance'),
          FutureBuilder(
            future: driversSvc.list(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snap.hasError) return ErrorCard(message: '${snap.error}');
              final rows = snap.data ?? const <Driver>[];
              return DropdownButton<Driver>(
                value: _selected,
                hint: const Text('Select driver'),
                items: rows
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                    .toList(),
                onChanged: (d) => setState(() => _selected = d),
              );
            },
          ),
          const SizedBox(height: 8),
          if (_selected != null)
            FutureBuilder(
              future: hosApi.get7DayLogs(_selected!.id),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError) return ErrorCard(message: '${snap.error}');
                final logs = snap.data ?? const <HosLog>[];
                if (logs.isEmpty) return const Text('No logs in past 7 days');
                return Card(
                  child: Column(
                    children: logs
                        .map(
                          (l) => ListTile(
                            leading: const Icon(Icons.event_note),
                            title: Text(
                              '${l.status.toUpperCase()} • ${l.startTimeUtc.toLocal()} → ${l.endTimeUtc.toLocal()}',
                            ),
                            subtitle: Text('Driver: ${_selected!.name}'),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
