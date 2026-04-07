import 'package:flutter/material.dart';

class AsyncErrorBanner extends StatelessWidget {
  final String errorText;
  final VoidCallback? onRetry;
  const AsyncErrorBanner({super.key, required this.errorText, this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Something went wrong'),
        subtitle: Text(errorText, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: onRetry == null
            ? null
            : TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ),
    );
  }
}

class EmptyPlaceholder extends StatelessWidget {
  final String message;
  const EmptyPlaceholder({super.key, required this.message});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Center(child: Text(message)),
  );
}
