import 'package:flutter/material.dart';

class UpgradeCard extends StatelessWidget {
  final String title;
  final VoidCallback onUpgrade;
  const UpgradeCard({super.key, required this.title, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('This is a premium feature. Upgrade to unlock it.'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onUpgrade, child: const Text('Upgrade')),
          ],
        ),
      ),
    );
  }
}
