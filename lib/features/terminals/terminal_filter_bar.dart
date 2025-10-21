import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/terminal_service.dart';

class TerminalFilterBar extends ConsumerWidget {
  const TerminalFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(terminalsProvider);
    final selected = ref.watch(selectedTerminalIdProvider);

    return Row(
      children: [
        const Icon(Icons.warehouse_outlined, size: 18),
        const SizedBox(width: 8),
        const Text('Terminal:'),
        const SizedBox(width: 8),
        DropdownButton<String?>(
          value: selected,
          items: [
            const DropdownMenuItem(child: Text('All')),
            ...terms.map(
              (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
            ),
          ],
          onChanged: (v) =>
              ref.read(selectedTerminalIdProvider.notifier).state = v,
        ),
        if (selected != null) ...[
          const SizedBox(width: 12),
          Text(
            terms.firstWhere((t) => t.id == selected).city,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
