// lib/promos/widgets/pin_widget.dart
import 'package:flutter/material.dart';

class PinWidget extends StatelessWidget {
  final String occupancy; // open|some|full|unknown
  final double confidence; // 0..1
  final bool selected;

  const PinWidget({
    super.key,
    required this.occupancy,
    required this.confidence,
    this.selected = false,
  });

  Color _colorFor(String occ) {
    switch (occ) {
      case 'open':
        return Colors.green;
      case 'some':
        return Colors.amber;
      case 'full':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _colorFor(occupancy);
    final outline = base.withValues(alpha: (0.4 + 0.6 * confidence).clamp(0.0, 1.0).toDouble());
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: base,
        border: Border.all(
          color: selected ? Colors.black87 : outline,
          width: selected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.35),
            blurRadius: selected ? 10 : 6,
            spreadRadius: selected ? 1 : 0.5,
          ),
        ],
      ),
      width: selected ? 28 : 24,
      height: selected ? 28 : 24,
      alignment: Alignment.center,
      child: const Icon(Icons.local_parking, color: Colors.white, size: 14),
    );
  }
}
