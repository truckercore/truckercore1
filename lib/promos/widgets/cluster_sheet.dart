// lib/promos/widgets/cluster_sheet.dart
import 'package:flutter/material.dart';
import '../model/stop_pin.dart';

class ClusterSheet extends StatelessWidget {
  final List<StopPin> stops;

  const ClusterSheet({super.key, required this.stops});

  @override
  Widget build(BuildContext context) {
    final sorted = [...stops]..sort((a, b) => computeStopScore(b).compareTo(computeStopScore(a)));
    final best = sorted.isNotEmpty ? sorted.first : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.place_outlined),
              const SizedBox(width: 8),
              Text('Stops nearby (${stops.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            if (best != null) ...[
              const SizedBox(height: 8),
              _BestTile(pin: best),
              const Divider(),
            ],
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _StopTile(pin: sorted[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestTile extends StatelessWidget {
  final StopPin pin;
  const _BestTile({required this.pin});

  @override
  Widget build(BuildContext context) {
    final f = computeFactors(pin);
    String badge;
    if (f['parking']! >= 0.9) {
      badge = 'Most parking';
    } else if ((pin.fuelDiscountCents ?? 0) >= 8) {
      badge = 'Cheapest fuel';
    } else {
      badge = 'Best for you';
    }
    return ListTile(
      leading: const Icon(Icons.star, color: Colors.amber),
      title: Text('${pin.name} • $badge'),
      subtitle: Text([
        'Dist ${pin.distanceMi.toStringAsFixed(1)} mi',
        'Conf ${(pin.confidence * 100).round()}%',
        if (pin.fuelDiscountCents != null) '${pin.fuelDiscountCents}¢ off'
      ].join(' • ')),
      trailing: const Text('Top'),
    );
  }
}

class _StopTile extends StatelessWidget {
  final StopPin pin;
  const _StopTile({required this.pin});

  @override
  Widget build(BuildContext context) {
    final occ = pin.occupancy;
    return ListTile(
      leading: Icon(Icons.local_gas_station, color: _colorFor(occ)),
      title: Text(pin.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        'Parking: $occ',
        'Conf ${(pin.confidence * 100).round()}%',
        'Dist ${pin.distanceMi.toStringAsFixed(1)} mi',
        if (pin.fuelDiscountCents != null) '${pin.fuelDiscountCents}¢ off'
      ].join(' • ')),
      onTap: () => Navigator.of(context).pop(pin),
    );
  }

  Color _colorFor(String occ) {
    switch (occ) {
      case 'open':
        return Colors.green;
      case 'some':
        return Colors.orange;
      case 'full':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
