// lib/features/flags_usage/flags_usage_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'flags_usage_service.dart';

class FlagsUsagePanel extends ConsumerWidget {
  const FlagsUsagePanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(flagsUsageServiceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.flag_outlined), SizedBox(width: 8), Text('Feature Flags & Usage', style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: svc.flags(),
            builder: (ctx, snap) {
              final flags = snap.data ?? const {};
              if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2));
              if (flags.isEmpty) return const Text('No flags set');
              return Wrap(spacing: 8, runSpacing: 8, children: flags.entries.map((e) => Chip(label: Text('${e.key}: ${e.value}'))).toList());
            },
          ),
          const Divider(),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: svc.usage(),
            builder: (ctx, snap) {
              final list = snap.data ?? const <Map<String, dynamic>>[];
              if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2));
              if (list.isEmpty) return const Text('No usage counters');
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = list[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.speed),
                    title: Text(m['key']?.toString() ?? ''),
                    subtitle: Text('count=${m['count']} • window=${m['window']}'),
                  );
                },
              );
            },
          ),
        ]),
      ),
    );
  }
}
