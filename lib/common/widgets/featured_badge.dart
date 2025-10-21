import 'package:flutter/material.dart';

class FeaturedBadge extends StatelessWidget {
  final bool featured;
  const FeaturedBadge({super.key, required this.featured});

  @override
  Widget build(BuildContext context) {
    if (!featured) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.shade600,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Featured',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}
