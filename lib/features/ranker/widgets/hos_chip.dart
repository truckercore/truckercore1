// lib/features/ranker/widgets/hos_chip.dart
// Null-safe UI helper chip for showing HOS adjustment.

import 'package:flutter/material.dart';

class HosChip extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  const HosChip({super.key, required this.suggestion});

  bool get _adjusted {
    final meta = (suggestion['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final v = meta['adjusted_for_hos'];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_adjusted) return const SizedBox.shrink();
    return Chip(
      avatar: const Icon(Icons.access_time),
      label: const Text('Adjusted for HOS'),
      backgroundColor: Colors.orange.shade50,
      side: BorderSide(color: Colors.orange.shade200),
      labelStyle: const TextStyle(color: Colors.black87),
      visualDensity: VisualDensity.compact,
    );
  }
}
