import 'package:flutter/material.dart';
import '../models/hos_models.dart';

class HOSStatusCard extends StatelessWidget {
  final HOSStatus status;

  const HOSStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    // Our HOSStatus model here is simplified (status + createdAt + details).
    // We render a compact summary with available info.
    final statusLabel = status.status.toUpperCase();
    final details = status.details ?? const {};
    final driveMinutes = (details['drive_minutes'] as num?)?.toInt();
    final dutyMinutes = (details['duty_minutes'] as num?)?.toInt();
    final cycleMinutes = (details['cycle_minutes'] as num?)?.toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hours of Service',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildStatusChip(statusLabel),
              ],
            ),
            const SizedBox(height: 16),
            if (driveMinutes != null)
              _buildTimeBar('Drive Time Remaining', driveMinutes, 660, Colors.blue),
            if (driveMinutes != null) const SizedBox(height: 12),
            if (dutyMinutes != null)
              _buildTimeBar('On-Duty Remaining', dutyMinutes, 840, Colors.orange),
            if (dutyMinutes != null) const SizedBox(height: 12),
            if (cycleMinutes != null)
              _buildTimeBar('Cycle Remaining', cycleMinutes, 4200, Colors.green),
            if (details['next_break_required'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Break required by ${details['next_break_required']}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'driving':
        color = Colors.green;
        break;
      case 'on_duty':
      case 'on duty':
        color = Colors.orange;
        break;
      case 'sleeper':
      case 'sleeper_berth':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTimeBar(String label, int remainingMinutes, int totalMinutes, Color color) {
    final clamped = remainingMinutes.clamp(0, totalMinutes);
    final percentage = totalMinutes == 0 ? 0.0 : clamped / totalMinutes;
    final hours = clamped ~/ 60;
    final minutes = clamped % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              '${hours}h ${minutes}m remaining',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
