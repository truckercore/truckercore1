import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiUsagePanel extends StatefulWidget {
  const AiUsagePanel({super.key});
  @override
  State<AiUsagePanel> createState() => _AiUsagePanelState();
}

class _AiUsagePanelState extends State<AiUsagePanel> {
  int reqUsed = 0, reqLimit = 0, costUsed = 0, costLimit = 0;
  bool loading = true;

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final orgId = c.auth.currentUser?.userMetadata?['org_id'];
    if (orgId == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month)
        .toIso8601String()
        .split('T')
        .first;

    final ql = await c
        .from('ai_quota_limits')
        .select('req_limit,cost_limit_cents,period_start')
        .eq('org_id', orgId)
        .maybeSingle();
    final au = await c
        .from('tenant_ai_usage')
        .select('request_count,cost_estimate_cents')
        .eq('org_id', orgId)
        .eq('period_start', periodStart)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      reqLimit = (ql?['req_limit'] ?? 10000) as int;
      costLimit = (ql?['cost_limit_cents'] ?? 50000) as int;
      reqUsed = (au?['request_count'] ?? 0) as int;
      costUsed = (au?['cost_estimate_cents'] ?? 0) as int;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final reqPct = reqLimit == 0 ? 0.0 : reqUsed / reqLimit;
    final costPct = costLimit == 0 ? 0.0 : costUsed / costLimit;
    final warn = reqPct >= 0.8 || costPct >= 0.8;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI usage this month', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Requests: $reqUsed / $reqLimit (${(reqPct * 100).toStringAsFixed(0)}%)'),
          LinearProgressIndicator(value: reqPct.clamp(0, 1)),
          const SizedBox(height: 8),
          Text('Cost: \$${(costUsed / 100).toStringAsFixed(2)} / \$${(costLimit / 100).toStringAsFixed(2)} (${(costPct * 100).toStringAsFixed(0)}%)'),
          LinearProgressIndicator(value: costPct.clamp(0, 1), color: Colors.orange),
          if (warn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Warning: >80% of quota consumed', style: TextStyle(color: Colors.red.shade700)),
            ),
        ]),
      ),
    );
  }
}
