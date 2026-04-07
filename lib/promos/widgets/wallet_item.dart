// lib/promos/widgets/wallet_item.dart
import 'package:flutter/material.dart';

class WalletItem extends StatelessWidget {
  final String title;
  final String brand;
  final String status; // Active / Paused / Cap reached
  final String? expiresLabel;
  final String? remainingUsesLabel;
  final VoidCallback onRedeem;

  const WalletItem({
    super.key,
    required this.title,
    required this.brand,
    required this.status,
    this.expiresLabel,
    this.remainingUsesLabel,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.local_offer),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        brand,
        if (expiresLabel != null) 'Expires $expiresLabel',
        if (remainingUsesLabel != null) remainingUsesLabel!,
      ].join(' • ')),
      trailing: ElevatedButton(
        onPressed: onRedeem,
        child: const Text('Redeem'),
      ),
    );
  }
}
