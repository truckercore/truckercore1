import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/remote_config.dart';
import '../../../services/supa_client.dart';

class DriverScorecardsScreen extends StatefulWidget {
  const DriverScorecardsScreen({super.key});
  @override
  State<DriverScorecardsScreen> createState() => _DriverScorecardsScreenState();
}

class _DriverScorecardsScreenState extends State<DriverScorecardsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  bool _enabled = true;

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
      // Remote flag (default true)
      final supaUrl = const String.fromEnvironment('SUPABASE_URL');
      final anon = const String.fromEnvironment('SUPABASE_ANON') != ''
          ? const String.fromEnvironment('SUPABASE_ANON')
          : const String.fromEnvironment('SUPABASE_ANON_KEY');
      final rc = RemoteConfig(SupaClient(supabaseUrl: supaUrl, anonKey: anon));
      try {
        await rc.refresh();
      } catch (_) {}
      _enabled = rc.get<bool>('feature_scorecards', true);
      if (!_enabled) {
        setState(() => _loading = false);
        return;
      }
      final c = Supabase.instance.client;
      final res = await c.from('v_driver_performance').select().limit(200);
      _rows = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Scorecards')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_enabled
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline),
                  const SizedBox(height: 8),
                  const Text('Scorecards are disabled by configuration'),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Driver',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text('Safety', textAlign: TextAlign.right),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text('HOS Today', textAlign: TextAlign.right),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text('On-time %', textAlign: TextAlign.right),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text('Composite', textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ..._rows.map((r) {
                    final name =
                        r['driver_name']?.toString() ??
                        (r['driver_user_id']?.toString() ?? 'driver');
                    final safety = (r['safety_score'] as num?)?.toDouble() ?? 0;
                    final hos = (r['hos_hours_today'] as num?)?.toDouble() ?? 0;
                    final ontime = (r['on_time_pct'] as num?)?.toDouble() ?? 0;
                    final comp =
                        (r['composite_score'] as num?)?.toDouble() ??
                        ((safety + ontime) / 2);
                    return Column(
                      children: [
                        ListTile(
                          dense: true,
                          title: Text(name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  safety.toStringAsFixed(0),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  '${hos.toStringAsFixed(1)} h',
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '${ontime.toStringAsFixed(0)}%',
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  comp.toStringAsFixed(0),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            /* navigate to detail when available */
                          },
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
