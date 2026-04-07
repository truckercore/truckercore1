// lib/widgets/usage_panel.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// NOTE: Replace this with your actual API client helper.
// It should POST to /usage_report Edge Function and return a JSON map
// with shape: { status: 'ok', data: { rows: [...] }, requestId }
Future<Map<String, dynamic>> apiPost(String path, {required Map<String, dynamic> body}) async {
  // Placeholder to avoid compile errors; integrate with your app's API layer.
  throw UnimplementedError('apiPost is not implemented. Wire this to your API client.');
}

class UsagePanel extends StatefulWidget {
  final DateTime start;
  final DateTime end;
  const UsagePanel({super.key, required this.start, required this.end});
  @override State<UsagePanel> createState() => _UsagePanelState();
}

class _UsagePanelState extends State<UsagePanel> {
  bool loading = true; String? error; List rows = [];
  @override void initState(){ super.initState(); _load(); }

  Future<void> _load() async {
    setState(()=>loading=true);
    try {
      final res = await apiPost('/usage_report', body:{
        'start': DateFormat('yyyy-MM-dd').format(widget.start),
        'end'  : DateFormat('yyyy-MM-dd').format(widget.end)
      });
      if (res['status'] != 'ok') throw Exception(res['message'] ?? 'error');
      setState(()=>rows = (res['data']?['rows'] ?? []) as List);
    } catch (e){ setState(()=>error = e.toString()); }
    finally { if (mounted) setState(()=>loading=false); }
  }

  @override Widget build(BuildContext ctx){
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Column(children:[
        Text('Failed to load usage: $error'),
        TextButton(onPressed: _load, child: const Text('Retry'))
      ]);
    }

    final Map<String, List<dynamic>> byFeat = {};
    for (final r in rows) {
      final fk = r['feature_key']?.toString() ?? 'unknown';
      byFeat.putIfAbsent(fk, ()=>[]).add(r);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
      for (final entry in byFeat.entries) _FeatureUsageCard(entry.key, entry.value),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _exportCsv(rows),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export CSV'),
        ),
      ),
    ]);
  }

  void _exportCsv(List data){
    final cols = ['feature_key','period','total_units','distinct_users'];
    final buffer = StringBuffer()..writeln(cols.join(','));
    for (final r in data) {
      buffer.writeln('${r['feature_key']},${r['period']},${r['total_units']},${r['distinct_users']}');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV generated (see logs or copy buffer)')));
  }
}

class _FeatureUsageCard extends StatelessWidget {
  final String feature; final List rows;
  const _FeatureUsageCard(this.feature, this.rows);

  @override Widget build(BuildContext context){
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(feature, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 12, children: rows.map<Widget>((r) =>
            Chip(label: Text("${DateFormat('MMM yyyy').format(DateTime.parse(r['period']))}: ${r['total_units']}"))).toList()),
          const Divider(),
          _MiniTable(rows: rows)
        ]),
      ),
    );
  }
}

class _MiniTable extends StatelessWidget {
  final List rows;
  const _MiniTable({required this.rows});
  @override Widget build(BuildContext context){
    return DataTable(columns: const [
      DataColumn(label: Text('Period')),
      DataColumn(label: Text('Units')),
      DataColumn(label: Text('Distinct users')),
    ], rows: rows.map<DataRow>((r) => DataRow(cells: [
      DataCell(Text(DateFormat('yyyy-MM').format(DateTime.parse(r['period'])))),
      DataCell(Text('${r['total_units']}')),
      DataCell(Text('${r['distinct_users']}')),
    ])).toList());
  }
}
