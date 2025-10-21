import 'package:flutter/material.dart';

/// Compact Hours-of-Service summary widget.
class HosSnapshot extends StatelessWidget {
  final Duration drivingRemaining;
  final Duration breakRemaining;
  final bool canDrive;
  final DateTime? lastLogAt;

  const HosSnapshot({
    super.key,
    required this.drivingRemaining,
    required this.breakRemaining,
    required this.canDrive,
    this.lastLogAt,
  });

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
    
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(canDrive ? Icons.directions_car : Icons.block, color: canDrive ? Colors.green : Colors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Driving remaining: ${_fmtDur(drivingRemaining)}', style: style.bodyMedium),
              const SizedBox(height: 4),
              Text('Break in: ${_fmtDur(breakRemaining)}', style: style.bodySmall),
              if (lastLogAt != null)
                Text('Last log: ${lastLogAt!.toLocal()}', style: style.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
