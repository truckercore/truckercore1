// lib/features/integrations/integrations_panel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/formatters.dart';
import 'integrations_service.dart';

class IntegrationsPanel extends ConsumerStatefulWidget {
  const IntegrationsPanel({super.key});
  @override
  ConsumerState<IntegrationsPanel> createState() => _IntegrationsPanelState();
}

class _IntegrationsPanelState extends ConsumerState<IntegrationsPanel> {
  bool _busy = false;
  final Map<String, String> _watch = {}; // provider -> outbox id
  final Map<String, StreamSubscription> _subs = {};

  Future<void> _refresh() async {
    setState(() {});
  }

  void _watchOutbox(String outboxId, String provider) {
    _subs[provider]?.cancel();
    final client = Supabase.instance.client;
    final sub = Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
      final row = await client.from('action_outbox').select('status,error').eq('id', outboxId).maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row as Map);
    }).listen((row) {
      if (!mounted || row == null) return;
      final status = row['status']?.toString() ?? 'pending';
      if (status == 'done') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Integration "$provider" updated')));
        _subs.remove(provider)?.cancel();
        setState(() { _watch.remove(provider); });
      } else if (status == 'failed') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Integration "$provider" failed')));
        _subs.remove(provider)?.cancel();
        setState(() { _watch.remove(provider); });
      }
    });
    _subs[provider] = sub;
  }

  @override
  void dispose() {
    for (final s in _subs.values) { s.cancel(); }
    _subs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(integrationsServiceProvider);
    return FutureBuilder<List<IntegrationItem>>(
      future: svc.list(),
      builder: (context, snap) {
        final items = snap.data ?? const <IntegrationItem>[];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.extension),
                    const SizedBox(width: 8),
                    const Text('Integrations', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh)),
                  ],
                ),
                const SizedBox(height: 8),
                if (snap.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                if (items.isEmpty && snap.connectionState == ConnectionState.done)
                  const Text('No integrations configured'),
                for (final it in items)
                  ListTile(
                    dense: true,
                    leading: Icon(it.status == 'connected' ? Icons.check_circle : it.status == 'error' ? Icons.error_outline : Icons.link_off),
                    title: Text(it.provider.toUpperCase()),
                    subtitle: Text('Status: ${it.status}${it.lastSyncAt != null ? ' • Last sync ${dateFmt(it.lastSyncAt!)}' : ''}'),
                    trailing: _watch.containsKey(it.provider)
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (it.status != 'connected')
                                TextButton(
                                  onPressed: _busy ? null : () async {
                                    setState(() => _busy = true);
                                    try {
                                      final id = await svc.connect(provider: it.provider);
                                      if (!mounted) return;
                                      setState(() { _watch[it.provider] = id; });
                                      _watchOutbox(id, it.provider);
                                    } finally { if (mounted) setState(() => _busy = false); }
                                  },
                                  child: const Text('Connect'),
                                ),
                              if (it.status == 'connected')
                                TextButton(
                                  onPressed: _busy ? null : () async {
                                    setState(() => _busy = true);
                                    try {
                                      final id = await svc.disconnect(provider: it.provider);
                                      if (!mounted) return;
                                      setState(() { _watch[it.provider] = id; });
                                      _watchOutbox(id, it.provider);
                                    } finally { if (mounted) setState(() => _busy = false); }
                                  },
                                  child: const Text('Disconnect'),
                                ),
                            ],
                          ),
                  ),
                const Divider(),
                // Exports quick action
                Row(children: [
                  const Icon(Icons.download_outlined),
                  const SizedBox(width: 8),
                  const Text('Exports'),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export CSV'),
                    onPressed: _busy ? null : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _busy = true);
                      try {
                        final id = await svc.triggerExport(format: 'csv');
                        if (!mounted) return;
                        messenger.showSnackBar(const SnackBar(content: Text('Export enqueued')));
                        _watchOutbox(id, 'export');
                      } finally { if (mounted) setState(() => _busy = false); }
                    },
                  )
                ]),
                const SizedBox(height: 8),
                // Calendar quick add
                Row(children: [
                  const Icon(Icons.event_available_outlined),
                  const SizedBox(width: 8),
                  const Text('Calendar'),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add sample event'),
                    onPressed: _busy ? null : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _busy = true);
                      try {
                        final now = DateTime.now();
                        final id = await svc.addCalendarEvent(title: 'Dispatch sync', start: now.add(const Duration(hours: 2)), end: now.add(const Duration(hours: 3)));
                        if (!mounted) return;
                        messenger.showSnackBar(const SnackBar(content: Text('Calendar event enqueued')));
                        _watchOutbox(id, 'calendar');
                      } finally { if (mounted) setState(() => _busy = false); }
                    },
                  )
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}
