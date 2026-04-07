import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/config/app_config.dart';

class OutboxHealth {
  final int pending;
  final int failed;
  final int dead;
  final Duration? oldestPendingAge;
  const OutboxHealth({required this.pending, required this.failed, required this.dead, required this.oldestPendingAge});
}

final outboxHealthProvider = FutureProvider<OutboxHealth>((ref) async {
  final cfg = ref.read(appConfigProvider);
  if (cfg.useMockData || cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) {
    return const OutboxHealth(pending: 2, failed: 1, dead: 0, oldestPendingAge: Duration(minutes: 3));
  }
  final c = Supabase.instance.client;
  try {
    final pendingRows = await c.from('action_outbox')
        .select('id, created_at')
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    final failedRows = await c.from('action_outbox').select('id').eq('status', 'failed').limit(1000);
    final deadRows = await c.from('action_outbox').select('id').eq('status', 'dead').limit(1000);

    final pendingList = (pendingRows as List?) ?? const [];
    final pendingCount = pendingList.length;
    Duration? oldestAge;
    if (pendingList.isNotEmpty) {
      final oldest = DateTime.tryParse((pendingList.first as Map)['created_at']?.toString() ?? '');
      if (oldest != null) {
        oldestAge = DateTime.now().toUtc().difference(oldest.toUtc());
      }
    }
    final failedCnt = ((failedRows as List?) ?? const []).length;
    final deadCnt = ((deadRows as List?) ?? const []).length;
    return OutboxHealth(pending: pendingCount, failed: failedCnt, dead: deadCnt, oldestPendingAge: oldestAge);
  } catch (_) {
    return const OutboxHealth(pending: 0, failed: 0, dead: 0, oldestPendingAge: null);
  }
});

String _fmtAge(Duration? d) {
  if (d == null) return 'oldest –';
  final m = d.inMinutes;
  if (m < 1) return 'oldest ${d.inSeconds}s';
  return 'oldest ${m}m';
}

class OutboxHealthCard extends ConsumerWidget {
  const OutboxHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(outboxHealthProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: async.when(
          data: (h) => Row(
            children: [
              const Icon(Icons.outbox),
              const SizedBox(width: 8),
              Text('${h.pending} pending, ${h.failed} failed', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text('(${_fmtAge(h.oldestPendingAge)})'),
              if (h.dead > 0) ...[
                const SizedBox(width: 12),
                Chip(label: Text('${h.dead} dead'), backgroundColor: Colors.red.shade50),
              ],
            ],
          ),
          error: (e, st) => const Text('Outbox status unavailable'),
          loading: () => const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }
}
