import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/load.dart';

class LoadCard extends StatelessWidget {
  const LoadCard({super.key, required this.load});

  final Load load;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to load details
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildRoute(context),
              const SizedBox(height: 12),
              _buildDetails(context),
              if (load.requirements != null && load.requirements!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildRequirements(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              load.loadNumber,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            _buildStatusChip(context),
          ],
        ),
        Text(
          '\$${load.rate.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color color;
    String label;

    switch (load.status) {
      case LoadStatus.posted:
        color = Colors.blue;
        label = 'POSTED';
        break;
      case LoadStatus.assigned:
        color = Colors.orange;
        label = 'ASSIGNED';
        break;
      case LoadStatus.inTransit:
        color = Colors.purple;
        label = 'IN TRANSIT';
        break;
      case LoadStatus.delivered:
        color = Colors.green;
        label = 'DELIVERED';
        break;
      case LoadStatus.cancelled:
        color = Colors.red;
        label = 'CANCELLED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoute(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildLocationPoint(
              context,
              '📍',
              load.origin.city,
              load.origin.state,
              _formatDate(load.pickupDate),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward, size: 20),
          ),
          Expanded(
            child: _buildLocationPoint(
              context,
              '🎯',
              load.destination.city,
              load.destination.state,
              _formatDate(load.deliveryDate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPoint(
    BuildContext context,
    String emoji,
    String city,
    String state,
    String date,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$city, $state',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          date,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Row(
      children: [
        _buildDetailItem(
          context,
          Icons.scale,
          '${(load.cargo.weight / 1000).toStringAsFixed(1)}k lbs',
        ),
        const SizedBox(width: 16),
        _buildDetailItem(
          context,
          Icons.straighten,
          '${load.distance.toStringAsFixed(0)} mi',
        ),
        const SizedBox(width: 16),
        _buildDetailItem(
          context,
          Icons.inventory_2_outlined,
          '${load.cargo.pieces} pcs',
        ),
      ],
    );
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildRequirements(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: load.requirements!.map((req) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            req,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, h:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
