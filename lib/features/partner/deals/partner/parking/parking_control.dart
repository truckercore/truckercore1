import 'package:flutter/material.dart';

class ParkingControls extends StatelessWidget {
  final int totalSpots;
  final int availableSpots;
  final bool liveEnabled; // Pro/Enterprise only
  final VoidCallback onPlusOne;
  final VoidCallback onMinusOne;
  final VoidCallback onLotFull;
  final VoidCallback onSaveBaseline; // sets total/available (from inputs)

  const ParkingControls({
    super.key,
    required this.totalSpots,
    required this.availableSpots,
    required this.liveEnabled,
    required this.onPlusOne,
    required this.onMinusOne,
    required this.onLotFull,
    required this.onSaveBaseline,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Save Baseline'),
          onPressed: onSaveBaseline,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.exposure_plus_1),
          label: const Text('+1'),
          onPressed: liveEnabled ? onPlusOne : null,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.exposure_neg_1),
          label: const Text('-1'),
          onPressed: liveEnabled ? onMinusOne : null,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.block),
          label: const Text('Lot Full'),
          onPressed: liveEnabled ? onLotFull : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    );
  }
}
