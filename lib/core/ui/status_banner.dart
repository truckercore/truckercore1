// lib/core/ui/status_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../flags/rollout_flags.dart';

class SystemStatus {
  final String status; // ok | degraded | down
  final String? message;
  const SystemStatus(this.status, {this.message});
}

final _systemStatusProvider = FutureProvider<SystemStatus>((ref) async {
  // Respect flags: if disabled, just return ok.
  final flags = ref.read(rolloutFlagsProvider);
  if (!flags.statusBannerEnabled) return const SystemStatus('ok');

  try {
    // If Supabase isn't configured, skip network call
    final client = Supabase.instance.client;
    // Detect configuration by checking if functions URL can be formed; if not initialized, functions invoke will throw.
    // We skip early using our own env config where possible.
    // Fall back to reading from app config provider would be better, but here we defensively try/catch.
    // If the client is the default uninitialized one, invoking will fail and we degrade gracefully.
    // No direct supabaseUrl getter available on the client type across versions.
    // Therefore we avoid accessing it and rely on try/catch below.
    // Proceed without explicit URL check.

    // Call Edge Function system_status if available
    final resp = await client.functions.invoke('system_status');
    final data = resp.data as Map<String, dynamic>?;
    final st = (data?['status']?.toString() ?? 'ok').toLowerCase();
    final msg = data?['message']?.toString();
    return SystemStatus(st, message: msg);
  } catch (_) {
    // On any error, degrade gracefully
    return const SystemStatus('degraded', message: 'Status unavailable');
  }
});

class StatusBanner extends ConsumerWidget {
  final Widget child;
  const StatusBanner({super.key, required this.child});

  Color _bg(String status) {
    switch (status) {
      case 'ok':
        return const Color(0xFF065F46); // green-900-ish
      case 'degraded':
        return const Color(0xFF92400E); // amber-800-ish
      case 'down':
        return const Color(0xFF7F1D1D); // red-900-ish
      default:
        return const Color(0xFF374151); // gray-700
    }
  }

  IconData _icon(String status) {
    switch (status) {
      case 'ok':
        return Icons.check_circle_outline;
      case 'degraded':
        return Icons.error_outline;
      case 'down':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _label(SystemStatus s) {
    switch (s.status) {
      case 'ok':
        return 'All systems nominal';
      case 'degraded':
        return 'Service degraded';
      case 'down':
        return 'Service down';
      default:
        return 'Status';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(rolloutFlagsProvider);
    if (!flags.statusBannerEnabled) return child;

    return FutureBuilder<SystemStatus>(
      future: ref.read(_systemStatusProvider.future),
      builder: (context, snap) {
        final stat = snap.data ?? const SystemStatus('ok');
        if (stat.status == 'ok') {
          // Minimal UI: either hide or show subtle banner. We'll show a very thin strip.
          return Column(
            children: [
              Material(
                color: _bg(stat.status),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 22,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon(stat.status), size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(_label(stat), style: const TextStyle(fontSize: 11, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          );
        }
        // degraded or down
        return Column(
          children: [
            Material(
              color: _bg(stat.status),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 28,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_icon(stat.status), size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          stat.message == null ? _label(stat) : '${_label(stat)} — ${stat.message}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
