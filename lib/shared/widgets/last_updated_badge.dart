import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters/time_format.dart' as fmt; // adjust path if needed

class LastUpdatedBadge extends ConsumerWidget {
  final DateTime? lastUpdated;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  const LastUpdatedBadge({super.key, required this.lastUpdated, required this.onRefresh, required this.isRefreshing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = 'Updated ${fmt.timeAgoShort(lastUpdated)}';
    final bg = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).colorScheme.outline;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(width: 8),
          SizedBox(
            width: 18,
            height: 18,
            child: isRefreshing
                ? const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 18, height: 18),
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh, size: 16),
                    onPressed: isRefreshing ? null : onRefresh,
                  ),
          ),
        ],
      ),
    );
  }
}
