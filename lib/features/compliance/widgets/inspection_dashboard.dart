import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InspectionDashboardScreen extends StatefulWidget {
  const InspectionDashboardScreen({super.key});
  @override
  State<InspectionDashboardScreen> createState() =>
      _InspectionDashboardScreenState();
}

class _InspectionDashboardScreenState extends State<InspectionDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = Supabase.instance.client;
      final res = await c
          .from('inspection_reports')
          .select(
            'id, driver_user_id, vehicle_id, type, defects, certified_safe, signed_at',
          )
          .order('signed_at', ascending: false)
          .limit(200);
      _rows = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspections')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = _rows[i];
                  final defects = (r['defects'] as List?) ?? const [];
                  final open =
                      defects.isNotEmpty && (r['certified_safe'] != true);
                  return ListTile(
                    leading: Icon(
                      open
                          ? Icons.warning_amber_outlined
                          : Icons.verified_outlined,
                      color: open ? Colors.orange : Colors.green,
                    ),
                    title: Text('${r['type']} • ${r['vehicle_id']}'),
                    subtitle: Text(
                      'Driver: ${r['driver_user_id']} • ${r['signed_at']}\nDefects: ${defects.length}',
                    ),
                    isThreeLine: true,
                    trailing: open
                        ? OutlinedButton(
                            onPressed: () async {
                              try {
                                final c = Supabase.instance.client;
                                await c.from('maintenance_jobs').insert({
                                  'org_id': null,
                                  'vehicle_id': r['vehicle_id'],
                                  'inspection_id': r['id'],
                                  'defect': (defects.isNotEmpty
                                      ? defects[0]
                                      : {'desc': 'unknown'}),
                                  'notes': 'Auto-created from inspection',
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Maintenance job created'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Fail: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('Create Job'),
                          )
                        : const SizedBox.shrink(),
                    onLongPress: open
                        ? () async {
                            // Resolve inspection
                            try {
                              final c = Supabase.instance.client;
                              await c
                                  .from('inspection_reports')
                                  .update({
                                    'resolved_at': DateTime.now()
                                        .toUtc()
                                        .toIso8601String(),
                                    'repair_notes': 'Resolved (quick action)',
                                  })
                                  .eq('id', r['id']);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Inspection resolved'),
                                  ),
                                );
                                await _load();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Resolve failed: $e')),
                                );
                              }
                            }
                          }
                        : null,
                  );
                },
              ),
            ),
    );
  }
}
