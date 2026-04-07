import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/config/app_config.dart';
import '../../core/observability/log_buffer.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String _ping = 'pending';
  @override
  void initState() {
    super.initState();
    _pingSupabase();
  }

  Future<void> _pingSupabase() async {
    try {
      if (!Supabase.instance.isInitialized) {
        setState(() => _ping = 'supabase not initialized');
        return;
      }
      final res = await Supabase.instance.client.rpc('select_1');
      setState(() => _ping = 'ok ${res.data}');
    } catch (e) {
      setState(() => _ping = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return const Scaffold(
        body: Center(child: Text('Diagnostics available in debug/profile only')),
      );
    }
    final cfg = appConfigFromEnv;
    final logs = LogBuffer.instance.takeLast(50).reversed.toList(growable: false);
    final lastErr = LogBuffer.instance.lastError;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('Environment', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('USE_MOCK=${cfg.useMockData}'),
            Text('SUPABASE_URL set=${cfg.supabaseUrl.isNotEmpty}'),
            Text('SENTRY_DSN set=${(const String.fromEnvironment('"SENTRY_DSN"')).isNotEmpty}'),
            const SizedBox(height: 12),
            const Text('Supabase ping', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_ping),
            const SizedBox(height: 12),
            const Text('Last 50 log lines', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black,
              child: SelectableText(
                logs.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Last error snapshot', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(lastErr ?? 'none'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Sentry.addBreadcrumb(Breadcrumb(message: 'manual test crumb', category: 'debug'));
                Sentry.captureMessage('manual test message from diagnostics');
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent test breadcrumb/message to Sentry')));
              },
              child: const Text('Send Sentry test breadcrumb/message'),
            ),
          ],
        ),
      ),
    );
  }
}
