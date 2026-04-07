import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ObservabilityAdminScreen extends StatefulWidget {
  const ObservabilityAdminScreen({super.key});

  @override
  State<ObservabilityAdminScreen> createState() => _ObservabilityAdminScreenState();
}

class _ObservabilityAdminScreenState extends State<ObservabilityAdminScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _statusBanner; // { mode, message, updated_at }
  List<Map<String, dynamic>> _kpiLatency = const [];
  List<Map<String, dynamic>> _kpiSiem = const [];
  List<Map<String, dynamic>> _kpiTrialPaid = const [];
  List<Map<String, dynamic>> _alarms = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final sb = Supabase.instance.client;

      // status_banner id=1
      try {
        final sbRow = await sb.from('status_banner').select('mode, message, updated_at').eq('id', 1).maybeSingle();
        if (sbRow != null) {
          _statusBanner = Map<String, dynamic>.from(sbRow as Map);
        }
      } catch (_) {}

      // KPIs
      Future<List<Map<String, dynamic>>> sel(String table, {String? order}) async {
        final res = await sb.from(table).select();
        final list = (res as List?)?.cast<Map<String, dynamic>>() ?? const [];
        if (order != null && list.isNotEmpty) {
          // naive: rely on server-side ordering if needed; keep as-is
        }
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      _kpiLatency = await sel('kpi_latency_p95_24h');
      _kpiSiem = await sel('kpi_siem_success_24h');
      _kpiTrialPaid = await sel('kpi_trial_to_paid_60d');

      // last alarms
      try {
        final rows = await sb.from('kpi_alarms')
            .select('ts, key, observed, level, info')
            .order('ts', ascending: false)
            .limit(20);
        _alarms = (rows as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [];
      } catch (_) {}

      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Color _levelColor(String? level) {
    switch ((level ?? '').toLowerCase()) {
      case 'critical':
      case 'error':
        return Colors.redAccent;
      case 'warn':
      case 'warning':
        return Colors.orangeAccent;
      case 'info':
      default:
        return Colors.blueGrey;
    }
  }

  Widget _kpiCard(String title, List<Map<String, dynamic>> rows, {List<String>? fields}) {
    final display = rows.take(4).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (display.isEmpty)
              const Text('No data', style: TextStyle(color: Colors.grey))
            else ...display.map((r) {
              final flds = fields ?? r.keys.take(4).toList();
              final text = flds.map((k) => '$k=${r[k]}').join('  ');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(text, style: const TextStyle(fontSize: 12)),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Observability'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Failed: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_statusBanner != null)
                        Card(
                          color: Colors.blueGrey.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.campaign_outlined),
                            title: Text((_statusBanner!['message'] ?? '').toString()),
                            subtitle: Text('mode: ${_statusBanner!['mode']} • updated: ${_statusBanner!['updated_at']}'),
                          ),
                        ),
                      _kpiCard('Latency p95 (24h)', _kpiLatency),
                      _kpiCard('SIEM Success (24h)', _kpiSiem),
                      _kpiCard('Trial → Paid (60d)', _kpiTrialPaid),
                      const SizedBox(height: 8),
                      const Text('Recent Alarms', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (_alarms.isEmpty)
                        const Text('No alarms', style: TextStyle(color: Colors.grey))
                      else ..._alarms.map((a) {
                        final level = (a['level'] ?? '').toString();
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.warning_amber_rounded, color: _levelColor(level)),
                            title: Text('${a['key']} • ${a['observed']}'),
                            subtitle: Text('${a['ts']}\n${jsonEncode(a['info'])}'),
                            isThreeLine: true,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
