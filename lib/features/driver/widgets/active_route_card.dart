import 'package:flutter/material.dart';

class ActiveRouteCard extends StatelessWidget {
  const ActiveRouteCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder for active route summary. In a full app, this would show the current route if any.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.route, color: Colors.blue),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No active route',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/navigation'),
              icon: const Icon(Icons.navigation),
              label: const Text('Plan'),
            ),
          ],
        ),
      ),
    );
  }
}
