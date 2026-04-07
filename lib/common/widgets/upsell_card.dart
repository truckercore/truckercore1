// lib/common/widgets/upsell_card.dart
import 'package:flutter/material.dart';

class UpsellCard extends StatelessWidget {
  final String feature;
  final String description;
  final String tierRequired; // 'premium' | 'ai'
  final VoidCallback onUpgrade;
  final VoidCallback? onLearnMore;
  final bool compact;

  const UpsellCard({
    super.key,
    required this.feature,
    required this.description,
    required this.tierRequired,
    required this.onUpgrade,
    this.onLearnMore,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final badge = tierRequired == 'ai' ? 'Roaddogg AI' : 'Premium';
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 28 : 34,
              height: compact ? 28 : 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: tierRequired == 'ai'
                    ? const LinearGradient(
                        colors: [Color(0xFF6D28D9), Color(0xFF0EA5E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(colors: [Color(0x1A0EA5E9), Color(0x1A0EA5E9)]),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.star, color: tierRequired == 'ai' ? Colors.white : const Color(0xFF0369A1), size: compact ? 14 : 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(feature, style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 14 : 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(999)),
                        child: Text(badge, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                      ),
                    ],
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 6),
                    Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    ElevatedButton(
                      onPressed: onUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tierRequired == 'ai' ? const Color(0xFF6D28D9) : const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(tierRequired == 'ai' ? 'Upgrade to AI' : 'Upgrade to Premium'),
                    ),
                    if (onLearnMore != null)
                      TextButton(onPressed: onLearnMore, child: const Text('Learn more')),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
