import 'package:flutter/material.dart';
import '../../fleet/data/fleet_repository.dart';

class NeedsAttentionList extends StatelessWidget {
  final List<AttentionItem> items;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;

  const NeedsAttentionList({
    super.key,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: List.generate(
          3,
          (i) => Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          children: [
            const Text('Failed to load'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Nothing needs attention right now.'),
          ],
        ),
      );
    }

    Color colorFor(String severity) {
      switch (severity) {
        case 'high':
          return const Color(0xFFFF6B6B);
        case 'med':
          return const Color(0xFFFFB020);
        default:
          return const Color(0xFF34D399);
      }
    }

    return Column(
      children: items
          .map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: ListTile(
                leading: Icon(Icons.priority_high, color: colorFor(e.severity)),
                title: Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  e.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: navigate to details
                },
              ),
            ),
          )
          .toList(),
    );
  }
}
