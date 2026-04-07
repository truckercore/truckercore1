import 'package:flutter/material.dart';

typedef PingFn = Future<Duration> Function();

/// A small diagnostics-aware footer showing connectivity and allowing a quick ping.
class HealthFooter extends StatefulWidget {
  final bool online;
  final String supabaseUrl;
  final String anonKey;
  final PingFn pingFn;

  const HealthFooter({
    super.key,
    required this.online,
    required this.supabaseUrl,
    required this.anonKey,
    required this.pingFn,
  });

  @override
  State<HealthFooter> createState() => _HealthFooterState();
}

class _HealthFooterState extends State<HealthFooter> {
  bool _busy = false;
  String? _last;

  @override
  Widget build(BuildContext context) {
    final ok = widget.online && widget.supabaseUrl.isNotEmpty && widget.anonKey.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(ok ? Icons.cloud_done : Icons.cloud_off, color: ok ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ok ? 'Online' : 'Offline',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (_last != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(_last!, style: Theme.of(context).textTheme.bodySmall),
              ),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        final d = await widget.pingFn();
                        if (!mounted) return;
                        setState(() => _last = 'Ping ${d.inMilliseconds} ms');
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.network_check),
              label: Text(_busy ? 'Pinging...' : 'Ping'),
            ),
          ],
        ),
      ),
    );
  }
}
