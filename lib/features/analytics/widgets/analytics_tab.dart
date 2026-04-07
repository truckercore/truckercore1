import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/widgets/error_card.dart';
import '../../../common/widgets/section_header.dart';
import '../../analytics/data/analytics_service.dart';

class AnalyticsTab extends ConsumerStatefulWidget {
  final String scope; // fleet | broker
  const AnalyticsTab({super.key, this.scope = 'fleet'});

  @override
  ConsumerState<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<AnalyticsTab> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().toUtc().subtract(const Duration(days: 29)),
    end: DateTime.now().toUtc(),
  );

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(analyticsServiceProvider);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          SectionHeader(
            title: widget.scope == 'broker'
                ? 'Broker Analytics'
                : 'Fleet Analytics',
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'range') {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365 * 2),
                    ),
                    lastDate: DateTime.now(),
                    initialDateRange: DateTimeRange(
                      start: _range.start.toLocal(),
                      end: _range.end.toLocal(),
                    ),
                  );
                  if (mounted && picked != null) {
                    setState(
                      () => _range = DateTimeRange(
                        start: picked.start.toUtc(),
                        end: picked.end.toUtc(),
                      ),
                    );
                  }
                } else if (v == 'export') {
                  final csv = await svc.exportCsv(
                    from: _range.start,
                    to: _range.end,
                    scope: widget.scope,
                  );
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('CSV Preview'),
                      content: SingleChildScrollView(
                        child: Text(
                          csv,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'range', child: Text('Change range')),
                PopupMenuItem(value: 'export', child: Text('Export CSV')),
              ],
            ),
          ),
          FutureBuilder<FleetAnalytics>(
            future: svc.getFleet(
              from: _range.start,
              to: _range.end,
              scope: widget.scope,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snap.hasError) return ErrorCard(message: '${snap.error}');
              final a = snap.data!;
              String usd(double v) => '\$${v.toStringAsFixed(2)}';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Loads: ${a.loads}')),
                      Chip(label: Text('Miles: ${a.miles.toStringAsFixed(1)}')),
                      Chip(label: Text('Revenue: ${usd(a.revenue)}')),
                      Chip(
                        label: Text('Avg PPM: ${a.avgPpm.toStringAsFixed(4)}'),
                      ),
                      Chip(
                        label: Text(
                          'On-time: ${a.onTimePct.toStringAsFixed(2)}%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trends',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (a.series.isEmpty)
                            const Text('No data in range')
                          else
                            ...a.series.map(
                              (p) => Row(
                                children: [
                                  SizedBox(
                                    width: 96,
                                    child: Text(
                                      p.date
                                          .toLocal()
                                          .toString()
                                          .split(' ')
                                          .first,
                                    ),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value:
                                          (p.loads /
                                                  (a.loads == 0 ? 1 : a.loads))
                                              .clamp(0.0, 1.0),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${p.loads} loads'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
