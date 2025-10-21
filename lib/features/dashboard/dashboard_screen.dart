import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../common/widgets/error_card.dart';
import '../../common/widgets/section_header.dart';
import '../compliance/widgets/compliance_alerts_panel.dart';
import '../fleet/data/fleet_repository.dart';
import 'widgets/kpi_bar.dart';
import 'widgets/needs_attention_list.dart';

final dashboardKpiProvider = FutureProvider.family<FleetKpis, DateTimeRange>((
  ref,
  range,
) async {
  final repo = ref.read(fleetRepositoryProvider);
  return repo.getKpis(range: range);
});

final needsAttentionProvider = FutureProvider<List<AttentionItem>>((ref) async {
  final repo = ref.read(fleetRepositoryProvider);
  return repo.getNeedsAttention();
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  Future<void> _showExportMenu(BuildContext context, FleetKpis? kpis, List<AttentionItem>? items) async {
    if (kpis == null && (items == null || items.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to export yet. Try again after data loads.')),
        );
      }
      return;
    }
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Export as PDF'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _exportPdf(kpis, items ?? const []);
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Export as CSV'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _exportCsv(kpis, items ?? const []);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportPdf(FleetKpis? kpis, List<AttentionItem> items) async {
    final doc = pw.Document();
    final rangeText = '${_range.start.toLocal().toString().split(".").first} → ${_range.end.toLocal().toString().split(".").first}';
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Fleet Dashboard', style: const pw.TextStyle(fontSize: 22))),
          pw.Text('Range: $rangeText'),
          pw.SizedBox(height: 12),
          pw.Text('KPIs', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Bullet(text: 'Active vehicles: \\${kpis?.activeVehicles ?? 0}'),
          pw.Bullet(text: 'Jobs today: \\${kpis?.jobsToday ?? 0}'),
          pw.Bullet(text: 'Delays: \\${kpis?.delays ?? 0}'),
          pw.Bullet(text: 'Alerts: \\${kpis?.alerts ?? 0}'),
          pw.SizedBox(height: 16),
          pw.Text('Needs Attention', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (items.isEmpty)
            pw.Text('No items')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['ID', 'Title', 'Subtitle', 'Severity'],
              data: items
                  .map((e) => [e.id, e.title, e.subtitle, e.severity])
                  .toList(),
            ),
          pw.SizedBox(height: 16),
          pw.Text('Generated on ${DateTime.now().toLocal()}'),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'dashboard_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  Future<void> _exportCsv(FleetKpis? kpis, List<AttentionItem> items) async {
    final rows = <List<dynamic>>[];
    rows.add(['Metric', 'Value']);
    rows.add(['Active vehicles', kpis?.activeVehicles ?? 0]);
    rows.add(['Jobs today', kpis?.jobsToday ?? 0]);
    rows.add(['Delays', kpis?.delays ?? 0]);
    rows.add(['Alerts', kpis?.alerts ?? 0]);
    rows.add([]);
    rows.add(['Needs Attention']);
    rows.add(['ID', 'Title', 'Subtitle', 'Severity']);
    for (final e in items) {
      rows.add([e.id, e.title, e.subtitle, e.severity]);
    }
    final csvStr = const ListToCsvConverter().convert(rows);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}dashboard_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvStr);

    await Share.shareXFiles([XFile(file.path)], subject: 'Dashboard export');
  }

  @override
  Widget build(BuildContext context) {
    final kpiAsync = ref.watch(dashboardKpiProvider(_range));
    final attnAsync = ref.watch(needsAttentionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _showExportMenu(context, kpiAsync.value, attnAsync.value),
          ),
          PopupMenuButton<String>(
            tooltip: 'Date range',
            onSelected: (v) {
              final now = DateTime.now();
              setState(() {
                switch (v) {
                  case 'today':
                    _range = DateTimeRange(start: now, end: now);
                    break;
                  case '7d':
                    _range = DateTimeRange(
                      start: now.subtract(const Duration(days: 6)),
                      end: now,
                    );
                    break;
                  case '30d':
                    _range = DateTimeRange(
                      start: now.subtract(const Duration(days: 29)),
                      end: now,
                    );
                    break;
                }
              });
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'today', child: Text('Today')),
              PopupMenuItem(value: '7d', child: Text('7 days')),
              PopupMenuItem(value: '30d', child: Text('30 days')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            KpiBar(
              kpis:
                  kpiAsync.value ??
                  const FleetKpis(
                    activeVehicles: 0,
                    jobsToday: 0,
                    delays: 0,
                    alerts: 0,
                  ),
              loading: kpiAsync.isLoading,
            ),
            const SizedBox(height: 16),

            // Map placeholder for now. Replace with your actual map later.
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: const Center(child: Text('Map goes here')),
            ),

            const SizedBox(height: 16),
            SectionHeader(
              title: 'Needs Attention',
              trailing: IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(needsAttentionProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            if (attnAsync.hasError)
              ErrorCard(
                message: 'Failed to load: ${attnAsync.error}',
                onRetry: () => ref.invalidate(needsAttentionProvider),
              )
            else
              NeedsAttentionList(
                items: attnAsync.value ?? const [],
                loading: attnAsync.isLoading,
                error: null,
                onRetry: () => ref.invalidate(needsAttentionProvider),
              ),

            const SizedBox(height: 16),
            // Compliance Alerts: uses tripRouteStreamProvider internally
            const ComplianceAlertsPanel(),
          ],
        ),
      ),
    );
  }
}
