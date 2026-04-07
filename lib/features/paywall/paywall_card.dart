import 'package:flutter/material.dart';

class PaywallCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onUpgrade;
  const PaywallCard({
    super.key,
    this.title = 'Upgrade to Pro',
    this.description = 'Unlock AI matching, ROI, Safety, IFTA, and more.',
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.lock_open, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed:
                  onUpgrade ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening billing portal...'),
                      ),
                    );
                  },
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}
