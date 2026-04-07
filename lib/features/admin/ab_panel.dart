// lib/features/admin/ab_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';

class _AbToggleService {
  final AppConfig cfg;
  const _AbToggleService(this.cfg);
  Future<bool> setEnabled({required String experimentKey, required bool enabled}) async {
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return false;
    final c = Supabase.instance.client;
    try {
      await c.functions.invoke('admin/experiments_toggle', body: {
        'experiment_key': experimentKey,
        'enabled': enabled,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

final _abToggleServiceProvider = Provider<_AbToggleService>((ref){
  final cfg = ref.watch(appConfigProvider);
  return _AbToggleService(cfg);
});

class AdminAbPanel extends ConsumerStatefulWidget {
  const AdminAbPanel({super.key});
  @override
  ConsumerState<AdminAbPanel> createState() => _AdminAbPanelState();
}

class _AdminAbPanelState extends ConsumerState<AdminAbPanel> {
  bool _busy = false;
  bool _enabled = true;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.science_outlined), SizedBox(width: 8), Text('Experiment Control', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            Row(children: [
              const Text('ranker_v1'),
              const Spacer(),
              Switch(
                value: _enabled,
                onChanged: _busy ? null : (v) async {
                  final messenger = ScaffoldMessenger.of(context);
                  setState(()=> _busy = true);
                  try {
                    final ok = await ref.read(_abToggleServiceProvider).setEnabled(experimentKey: 'ranker_v1', enabled: v);
                    if (ok) setState(()=> _enabled = v);
                    messenger.showSnackBar(SnackBar(content: Text(ok ? 'Saved' : 'Failed')));
                  } finally { if (mounted) setState(()=> _busy = false); }
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
