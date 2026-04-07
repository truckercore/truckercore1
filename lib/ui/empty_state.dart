import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String tip;
  final Widget? illustration; // e.g., an asset or Icon
  final EdgeInsets padding;

  const EmptyState({
    super.key,
    required this.title,
    required this.tip,
    this.illustration,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                Icon(Icons.inbox_outlined, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              tip,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
