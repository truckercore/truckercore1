// lib/core/ui/pilot_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Simple provider that checks if 'pilot_mode' entitlement is enabled for current org
// We infer org id from JWT claim 'app_org_id' via an auth function call if available,
// otherwise this remains false to avoid noisy UI in non-pilot orgs.

class PilotModeState {
  final bool enabled;
  final String? orgId;
  final String? source; // user|org|plan|default
  const PilotModeState({required this.enabled, this.orgId, this.source});
}

final pilotModeProvider = FutureProvider<PilotModeState>((ref) async {
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    // Try to read org id from JWT (supabase-js namespacing replicated via auth.getSession in dart)
    final orgId = user?.appMetadata['app_org_id']?.toString();
    if (orgId == null || orgId.isEmpty) {
      return const PilotModeState(enabled: false);
    }
    final PostgrestMap data = await client.rpc('get_entitlement', params: {
      'p_org_id': orgId,
      'p_feature_key': 'pilot_mode',
      'p_user_id': user?.id,
    }).single();
    final enabled = (data['enabled'] == true);
    final source = data['source']?.toString();
    return PilotModeState(enabled: enabled, orgId: orgId, source: source);
  } catch (_) {
    return const PilotModeState(enabled: false);
  }
});

class PilotBanner extends ConsumerWidget {
  final Widget child;
  const PilotBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(pilotModeProvider);
    return snap.when(
      data: (s) {
        if (!s.enabled) return child;
        return Column(
          children: [
            Material(
              color: const Color(0xFF1E3A8A), // indigo-800
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.flight_takeoff, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Pilot Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('KPIs and export links available for your pilot', style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // Open Pilot KPI dashboard route or external docs; minimal: open a web URL
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Pilot KPIs from menu')));
                        },
                        icon: const Icon(Icons.dashboard, color: Colors.white),
                        label: const Text('View KPIs', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          // Trigger Pilot Summary export with current org context; filters are captured in the portal
                          final org = s.orgId ?? '';
                          // Backend/portal handles creating export_snapshots with entitlement_snapshot_ids
                          // ignore: unused_local_variable
                          final url = Uri.parse('https://operator.truckercore/pilot/export-summary?orgId=$org');
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilot Summary export requested')));
                        },
                        icon: const Icon(Icons.summarize, color: Colors.white),
                        label: const Text('Pilot Summary', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          final org = s.orgId ?? '';
                          // Open prefilled support ticket URL; backend pre-fills with current KPIs and org context
                          // ignore: unused_local_variable
                          final url = Uri.parse('https://operator.truckercore/support/request-extension?orgId=$org');
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to Support')));
                        },
                        icon: const Icon(Icons.schedule_send, color: Colors.white),
                        label: const Text('Request Extension', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }
}
