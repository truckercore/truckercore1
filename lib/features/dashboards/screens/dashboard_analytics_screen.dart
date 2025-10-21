import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_metadata.dart';
import '../services/dashboard_analytics.dart';

class DashboardAnalyticsScreen extends ConsumerWidget {
  const DashboardAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboards Analytics')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _PopularDashboardsCard()),
                const SizedBox(width: 16),
                Expanded(child: _EngagementCard()),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _EventsBreakdownTable()),
          ],
        ),
      ),
    );
  }
}

class _PopularDashboardsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, int>>(
          future: DashboardAnalytics.getMostUsed(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
            }
            final counts = snap.data!;
            if (counts.isEmpty) {
              return const SizedBox(height: 140, child: Center(child: Text('No usage in last 30 days')));
            }
            // Map ids to metadata names/colors when available
            final byName = counts.entries.map((e) {
              final meta = availableDashboards.where((d) => d.id == e.key).cast<DashboardMetadata?>().firstOrNull;
              return _DashCount(name: meta?.name ?? e.key, count: e.value, color: meta?.color ?? Colors.blueGrey);
            }).toList()
              ..sort((a, b) => b.count.compareTo(a.count));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Most Popular Dashboards', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...byName.take(5).map((row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: row.color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text(row.count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EngagementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, int>>(
          future: DashboardAnalytics.getCountsByAction(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
            }
            final actions = snap.data!;
            final opens = actions['open'] ?? 0;
            final previews = actions['preview'] ?? 0;
            final previewOpen = actions['preview_open'] ?? 0;
            final shares = actions['share'] ?? 0;
            final shareImports = actions['share_import'] ?? 0;

            double ratio(int a, int b) => b == 0 ? 0 : (a / b * 100.0);

            final previewToOpen = ratio(previewOpen, previews);
            final shareSuccess = ratio(shareImports, shares);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Engagement Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _KpiTile(label: 'Opens (30d)', value: opens.toString(), color: Colors.lightBlue),
                    _KpiTile(label: 'Previews (30d)', value: previews.toString(), color: Colors.deepPurple),
                    _KpiTile(label: 'Preview→Open %', value: '${previewToOpen.toStringAsFixed(1)}%', color: Colors.green),
                    _KpiTile(label: 'Shares', value: shares.toString(), color: Colors.orange),
                    _KpiTile(label: 'Share success %', value: '${shareSuccess.toStringAsFixed(1)}%', color: Colors.teal),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventsBreakdownTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, int>>(
          future: DashboardAnalytics.getCountsByAction(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final actions = snap.data!;
            final rows = actions.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Events Breakdown (30d)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Event')),
                        DataColumn(label: Text('Count'), numeric: true),
                      ],
                      rows: rows
                          .map((e) => DataRow(cells: [
                                DataCell(Text(e.key)),
                                DataCell(Text(e.value.toString())),
                              ]))
                          .toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashCount {
  final String name;
  final int count;
  final Color color;
  _DashCount({required this.name, required this.count, required this.color});
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}
