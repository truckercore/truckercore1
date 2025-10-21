import 'package:flutter/material.dart';

import '../../../common/gating/feature_gate.dart';
import '../../../services/supa_client.dart';
import '../../../services/supabase_safe.dart';

/// Analytics screen for lane ROI and detention hotspots.
class OpsProfitDetentionScreen extends StatefulWidget {
  final SupaClient client;
  const OpsProfitDetentionScreen({super.key, required this.client});

  @override
  State<OpsProfitDetentionScreen> createState() =>
      _OpsProfitDetentionScreenState();
}

class _OpsProfitDetentionScreenState extends State<OpsProfitDetentionScreen> {
  // Filters and paging
  String _range = '30'; // 7|30|90 days
  final int _limit = 20;
  int _offset = 0;
  String _laneSort = 'profit_usd.desc';
  String _facSort = 'avg_minutes.desc';
  bool _loading = false;
  DateTime? _t0;
  DateTime? _t1;
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    setState(() {
      _loading = true;
    });
    final nowUtc = DateTime.now().toUtc();
    final days = int.tryParse(_range) ?? 30;
    _t1 = nowUtc;
    _t0 = nowUtc.subtract(Duration(days: days));
    final qRange =
        '&since=${_t0!.toIso8601String()}&until=${_t1!.toIso8601String()}';
    final laneSort = _laneSort.contains('.') ? _laneSort : '$_laneSort.desc';
    final facSort = _facSort.contains('.') ? _facSort : '$_facSort.desc';
    final tStart = DateTime.now();
    final lanes = await widget.client.getJson(
      '/v_lane_roi_and_detention?select=*&order=$laneSort&limit=$_limit&offset=$_offset$qRange',
      timeout: const Duration(seconds: 10),
    );
    final facs = await widget.client.getJson(
      '/v_detention_by_facility?select=*&order=$facSort&limit=$_limit&offset=$_offset$qRange',
      timeout: const Duration(seconds: 10),
    );
    setState(() {
      _loading = false;
    });
    // Metrics: page load/query duration (best-effort)
    try {
      final ms = DateTime.now().difference(tStart).inMilliseconds;
      await SupabaseSafe.runIfReady(
        (c) => c.from('metrics_events').insert({
          'kind': 'analytics_page_load',
          'props': {
            'page': 'ops_profit_detention',
            'range_days': days,
            'lane_sort': laneSort,
            'fac_sort': facSort,
            'limit': _limit,
            'offset': _offset,
            'ms': ms,
          },
        }),
      );
    } catch (_) {}
    List<Map<String, dynamic>> asListOfMap(dynamic v) {
      if (v is List) {
        return v.map((e) {
          final Map<String, dynamic> out = <String, dynamic>{};
          if (e is Map) {
            e.forEach((k, val) {
              out[k.toString()] = val;
            });
          }
          return out;
        }).toList();
      }
      if (v is Map && v['data'] is List) {
        final l = v['data'] as List;
        return l.map((e) {
          final Map<String, dynamic> out = <String, dynamic>{};
          if (e is Map) {
            e.forEach((k, val) {
              out[k.toString()] = val;
            });
          }
          return out;
        }).toList();
      }
      return const <Map<String, dynamic>>[];
    }

    return _Data(lanes: asListOfMap(lanes), facilities: asListOfMap(facs));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ROI + Detention Analytics'),
        actions: [
          // Time range selector
          DropdownButton<String>(
            value: _range,
            items: const [
              DropdownMenuItem(value: '7', child: Text('7d')),
              DropdownMenuItem(value: '30', child: Text('30d')),
              DropdownMenuItem(value: '90', child: Text('90d')),
            ],
            onChanged: (v) {
              setState(() => _range = v ?? '30');
              _future = _load();
            },
          ),
          FutureBuilder<bool>(
            future: FeatureGate.has('roi'),
            builder: (context, snap) {
              final allowed = snap.data == true;
              return IconButton(
                tooltip: allowed ? 'Export CSV' : 'Export (Pro)',
                icon: const Icon(Icons.download),
                onPressed: !_loading && allowed
                    ? () async {
                        // Minimal CSV export of current lanes rows
                        final data = await _future;
                        final buf = StringBuffer(
                          'origin,destination,loads,profit_usd,avg_ppm,dest_avg_detention_min\n',
                        );
                        for (final r in data.lanes) {
                          buf.writeln(
                            '${r['origin'] ?? ''},${r['destination'] ?? ''},${r['loads'] ?? 0},${r['profit_usd'] ?? 0},${r['avg_ppm'] ?? ''},${r['dest_avg_detention_min'] ?? ''}',
                          );
                        }
                        // In a real app, write to file or share; here, just show a snackbar confirming
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('CSV prepared (mock)')),
                        );
                      }
                    : null,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data as _Data;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // KPI row
              Wrap(
                runSpacing: 12,
                spacing: 12,
                children: [
                  _Kpi(
                    label: 'Top Lane Profit',
                    value: _fmtMoney(_topProfit(data.lanes)),
                  ),
                  _Kpi(
                    label: 'Worst Detention (min)',
                    value: _worstDet(data.facilities).toString(),
                  ),
                  _Kpi(
                    label: 'Facilities Tracked',
                    value: data.facilities.length.toString(),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Text(
                'Best Lanes by Profit',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Sort:'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _laneSort,
                    items: const [
                      DropdownMenuItem(
                        value: 'profit_usd.desc',
                        child: Text('Profit ⬇'),
                      ),
                      DropdownMenuItem(
                        value: 'avg_ppm.desc',
                        child: Text('PPM ⬇'),
                      ),
                      DropdownMenuItem(
                        value: 'loads.desc',
                        child: Text('Loads ⬇'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _laneSort = v ?? 'profit_usd.desc');
                      _future = _load();
                    },
                  ),
                ],
              ),
              _LaneTable(rows: data.lanes),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _offset <= 0
                        ? null
                        : () {
                            setState(
                              () =>
                                  _offset = (_offset - _limit).clamp(0, 100000),
                            );
                            _future = _load();
                          },
                    child: const Text('Prev'),
                  ),
                  Text('Offset: $_offset'),
                  TextButton(
                    onPressed: () {
                      setState(() => _offset += _limit);
                      _future = _load();
                    },
                    child: const Text('Next'),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Text(
                'Detention Hotspots',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Sort:'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _facSort,
                    items: const [
                      DropdownMenuItem(
                        value: 'avg_minutes.desc',
                        child: Text('Avg Detention ⬇'),
                      ),
                      DropdownMenuItem(
                        value: 'visits.desc',
                        child: Text('Visits ⬇'),
                      ),
                      DropdownMenuItem(
                        value: 'last_seen.desc',
                        child: Text('Last Seen ⬇'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _facSort = v ?? 'avg_minutes.desc');
                      _future = _load();
                    },
                  ),
                ],
              ),
              _FacilityTable(rows: data.facilities),

              const SizedBox(height: 18),
              _MapHint(),
            ],
          );
        },
      ),
    );
  }

  String _fmtMoney(num? v) => v == null ? '--' : '\$${v.toStringAsFixed(2)}';
  num? _topProfit(List<Map<String, dynamic>> lanes) => lanes.isEmpty
      ? null
      : (lanes.firstWhere((_) => true)['profit_usd'] as num?);
  int _worstDet(List<Map<String, dynamic>> facs) => facs.isEmpty
      ? 0
      : (((facs.firstWhere((_) => true)['avg_minutes'] ?? 0) as num).round());
}

class _Data {
  final List<Map<String, dynamic>> lanes;
  final List<Map<String, dynamic>> facilities;
  _Data({required this.lanes, required this.facilities});
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  const _Kpi({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaneTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _LaneTable({required this.rows});
  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort(
        (a, b) => ((b['profit_usd'] ?? 0) as num).compareTo(
          (a['profit_usd'] ?? 0) as num,
        ),
      );
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Origin')),
            DataColumn(label: Text('Destination')),
            DataColumn(label: Text('Loads')),
            DataColumn(label: Text('Profit')),
            DataColumn(label: Text('PPM')),
            DataColumn(label: Text('Dest Det (min)')),
          ],
          rows: sorted
              .take(20)
              .map(
                (r) => DataRow(
                  cells: [
                    DataCell(Text('${r['origin'] ?? ''}')),
                    DataCell(Text('${r['destination'] ?? ''}')),
                    DataCell(Text('${r['loads'] ?? 0}')),
                    DataCell(
                      Text(
                        '\$${((r['profit_usd'] ?? 0) as num).toStringAsFixed(2)}',
                      ),
                    ),
                    DataCell(
                      Text(
                        r['avg_ppm'] == null
                            ? '--'
                            : ((r['avg_ppm'] as num).toStringAsFixed(2)),
                      ),
                    ),
                    DataCell(Text('${r['dest_avg_detention_min'] ?? '--'}')),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _FacilityTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _FacilityTable({required this.rows});
  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort(
        (a, b) => ((b['avg_minutes'] ?? 0) as num).compareTo(
          (a['avg_minutes'] ?? 0) as num,
        ),
      );
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Facility')),
            DataColumn(label: Text('Visits')),
            DataColumn(label: Text('Avg Detention (min)')),
            DataColumn(label: Text('Last Seen')),
          ],
          rows: sorted
              .take(20)
              .map(
                (r) => DataRow(
                  cells: [
                    DataCell(Text('${r['facility_name'] ?? 'Unknown'}')),
                    DataCell(Text('${r['visits'] ?? 0}')),
                    DataCell(Text('${r['avg_minutes'] ?? 0}')),
                    DataCell(Text('${r['last_seen'] ?? ''}')),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MapHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.withValues(alpha: 0.06),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Tip: Open the Fleet Map and toggle “Detention Hotspots” to see bubbles at facility centroids. '
          'This uses v_detention_by_facility + v_facilities (centroids).',
        ),
      ),
    );
  }
}
