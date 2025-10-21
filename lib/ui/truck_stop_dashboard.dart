import 'package:flutter/material.dart';

class TruckStopDashboard extends StatelessWidget {
  const TruckStopDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Truck Stop Operator Portal')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          children: [
            const _DashCard('Push Promo', Icons.campaign, 'Send deals to nearby drivers'),
            const _DashCard('Parking Dashboard', Icons.local_parking, 'Live available spots / sections'),
            const _DashCard('Fuel & Pricing', Icons.local_gas_station, 'Publish latest prices/inventory'),
            const _DashCard('Feedback/Alerts', Icons.feedback, 'See reviews & urgent issues'),
            const _DashCard('Receipts', Icons.receipt, 'Digital fuel logs/exports'),
            const _DashCard('Analytics', Icons.bar_chart, 'Peak demand, staffing, sales'),
            const _DashCard('Premium Portal', Icons.stars, 'Customer analytics, TMS integrations'),
            _DashCard('Observability', Icons.monitor_heart, 'Metrics & request tracing', onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Observability'),
                  content: const Text('Edge Functions emit metrics via audit_log (metrics.*). Use Supabase SQL to view recent request_ids and latency.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final String label, sub;
  final IconData icon;
  final VoidCallback? onTap;
  const _DashCard(this.label, this.icon, this.sub, {this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.orange[800]),
                const SizedBox(height: 10),
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}
