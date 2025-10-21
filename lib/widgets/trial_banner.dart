import 'package:flutter/material.dart';

class TrialBanner extends StatelessWidget {
  final DateTime? expiresAt;
  const TrialBanner({super.key, this.expiresAt});
  @override
  Widget build(BuildContext context) {
    if (expiresAt == null) return const SizedBox.shrink();
    final days = expiresAt!.difference(DateTime.now()).inDays;
    final msg = days >= 0 ? 'Trial ends in $days days' : 'Trial expired';
    return Card(
        color: Colors.amber.shade50,
        child: ListTile(
          leading: const Icon(Icons.hourglass_bottom),
          title: Text(msg),
          trailing: ElevatedButton(onPressed: () {}, child: const Text('Upgrade')),
        ));
  }
}
