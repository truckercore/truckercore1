import 'package:flutter/material.dart';

class OwnerOpDashboard extends StatelessWidget {
  const OwnerOpDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My TMS Cockpit')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Welcome, get big-fleet power in your pocket.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: [
                DashboardCard(
                  title: 'Smart Load Match',
                  icon: Icons.star,
                  desc: 'Find best loads for my truck',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Call AI matcher (stub)')),
                    );
                  },
                ),
                DashboardCard(
                  title: 'Start Trip',
                  icon: Icons.local_shipping,
                  desc: 'Accept a load, auto-build trip plan',
                  onTap: () {},
                ),
                DashboardCard(
                  title: 'Route & Fuel',
                  icon: Icons.map,
                  desc: 'Best route, weigh stations, fuel stops',
                  onTap: () {},
                ),
                DashboardCard(
                  title: 'ELD / Logbook',
                  icon: Icons.assignment_turned_in,
                  desc: 'Digital logs & IFTA',
                  onTap: () {},
                ),
                DashboardCard(
                  title: 'Invoices',
                  icon: Icons.attach_money,
                  desc: 'Create/send digital invoices',
                  onTap: () {},
                ),
                DashboardCard(
                  title: 'Expenses',
                  icon: Icons.receipt,
                  desc: 'Track costs per trip/mile',
                  onTap: () {},
                ),
                DashboardCard(
                  title: 'Maintenance',
                  icon: Icons.build,
                  desc: 'Reminders, repair log, downtime',
                  onTap: () {},
                ),
                const RoadDoggAICard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title, desc;
  final IconData icon;
  final VoidCallback? onTap;
  const DashboardCard({super.key, required this.title, required this.icon, required this.desc, this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.green[700]),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}

class RoadDoggAICard extends StatefulWidget {
  const RoadDoggAICard({super.key});

  @override
  State<RoadDoggAICard> createState() => _RoadDoggAICardState();
}

class _RoadDoggAICardState extends State<RoadDoggAICard> {
  final _controller = TextEditingController();
  String _response = '';

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const Text('Ask RoadDogg (AI Coach)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: r'Why is my $/mile so low this week?'),
                onSubmitted: (query) async {
                  setState(() => _response = 'Thinking...');
                  await Future.delayed(const Duration(seconds: 1));
                  setState(() => _response = r'AI: Fuel at TA in Chicago would save $29 this trip.');
                },
              ),
              if (_response.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_response, style: TextStyle(color: Colors.green[900])),
                ),
            ],
          ),
        ),
      );
}
