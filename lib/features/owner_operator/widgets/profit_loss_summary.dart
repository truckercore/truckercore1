import 'package:flutter/material.dart';

class ProfitLossSummary extends StatelessWidget {
  const ProfitLossSummary({super.key});

  @override
  Widget build(BuildContext context) {
    // Minimal placeholder summary; in a real app this would query service
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profit & Loss Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gross Revenue', style: TextStyle(color: Colors.grey)),
                Text('\$25,400', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Operating Expenses', style: TextStyle(color: Colors.grey)),
                Text('\$12,900', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Income', style: TextStyle(color: Colors.grey)),
                Text('\$12,500', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
