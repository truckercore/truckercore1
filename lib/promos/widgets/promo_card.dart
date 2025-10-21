// lib/promos/widgets/promo_card.dart
import 'package:flutter/material.dart';

class PromoCard extends StatelessWidget {
  final String brand;
  final String title;
  final String subtitle;           // e.g., "10¢/gal off"
  final String distanceLabel;      // e.g., "3.2 mi"
  final String parkingBadge;       // Open / Limited / Full
  final double? confidence;        // 0..1
  final List<String> badges;       // e.g., ["2x Points", "This stop only"]
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onRedeem;

  const PromoCard({
    super.key,
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.distanceLabel,
    required this.parkingBadge,
    this.confidence,
    this.badges = const [],
    this.saved = false,
    required this.onSave,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(brand)),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(distanceLabel)),
                Chip(label: Text('Parking: $parkingBadge')),
                if (confidence != null) Chip(label: Text('Conf ${(confidence! * 100).round()}%')),
                for (final b in badges) Chip(label: Text(b)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onSave,
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_add_outlined),
                  label: Text(saved ? 'Saved' : 'Add to Wallet'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onRedeem,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Tap to Redeem'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
