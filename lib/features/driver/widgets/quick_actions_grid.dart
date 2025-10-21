import 'package:flutter/material.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildActionButton(
                  context,
                  'DVIR',
                  Icons.assignment_turned_in,
                  Colors.blue,
                  () => Navigator.pushNamed(context, '/dvir'),
                ),
                _buildActionButton(
                  context,
                  'Find Parking',
                  Icons.local_parking,
                  Colors.green,
                  () => Navigator.pushNamed(context, '/parking'),
                ),
                _buildActionButton(
                  context,
                  'Fuel Prices',
                  Icons.local_gas_station,
                  Colors.orange,
                  () => Navigator.pushNamed(context, '/fuel'),
                ),
                _buildActionButton(
                  context,
                  'Weigh Stations',
                  Icons.scale,
                  Colors.purple,
                  () => Navigator.pushNamed(context, '/weigh-stations'),
                ),
                _buildActionButton(
                  context,
                  'Documents',
                  Icons.folder,
                  Colors.teal,
                  () => Navigator.pushNamed(context, '/documents'),
                ),
                _buildActionButton(
                  context,
                  'Messages',
                  Icons.message,
                  Colors.pink,
                  () => Navigator.pushNamed(context, '/messages'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
