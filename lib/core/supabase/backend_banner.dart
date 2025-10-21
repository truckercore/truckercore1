// lib/core/supabase/backend_banner.dart
// Lightweight health probe and warning banner for Supabase backend status.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Quick helper alias. Access only after Supabase.initialize has run.
SupabaseClient get supa => Supabase.instance.client;

/// Simple health probe: reads from a public 'health_ping_view' with anon read policy.
Future<String> pingBackend() async {
  try {
    final resp = await supa.from('health_ping_view').select('now').limit(1);
    final n = (resp as List).length;
    return 'ok ($n)';
  } catch (e) {
    return 'error: $e';
  }
}

/// Optional banner that shows when health probe is not ok.
class BackendBanner extends StatefulWidget {
  const BackendBanner({super.key});
  @override
  State<BackendBanner> createState() => _BackendBannerState();
}

class _BackendBannerState extends State<BackendBanner> {
  String _status = 'checking…';

  @override
  void initState() {
    super.initState();
    pingBackend().then((s) {
      if (!mounted) return;
      setState(() => _status = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOk = _status.startsWith('ok');
    if (isOk) return const SizedBox.shrink();
    return Container(
      color: Colors.orange,
      padding: const EdgeInsets.all(8),
      width: double.infinity,
      child: Text(
        'Backend issue: $_status',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
