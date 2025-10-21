import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/widgets/app_background.dart';
import '../../common/widgets/role_badge.dart';

class PartnerDashboardScreen extends ConsumerWidget {
  const PartnerDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truck Stop Partner Dashboard'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: RoleBadge()),
          ),
        ],
      ),
      body: const AppBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                title: 'Fuel Sales (Summary)',
                subtitle:
                    'Aggregate sales if integrated with TruckerCore fuel card',
                child: _FuelSalesStub(),
              ),
              _SectionCard(
                title: 'Help & Training',
                subtitle: 'Tutorials for partners',
                child: _PartnerHelpStub(),
              ),
              _SectionCard(
                title: 'Support Tickets',
                subtitle: 'Create and track tickets',
                child: _PartnerTicketsStub(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _FuelSalesStub extends StatelessWidget {
  const _FuelSalesStub();
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.local_gas_station),
          title: Text('Last 30 days'),
          subtitle: Text('Total gallons: 42,310 • Revenue: \$162,780'),
        ),
        ListTile(
          leading: Icon(Icons.trending_up),
          title: Text('MoM Change'),
          subtitle: Text('+6.2%'),
        ),
      ],
    );
  }
}

class _PartnerHelpStub extends StatelessWidget {
  const _PartnerHelpStub();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.park_outlined),
          title: Text('How to post parking availability'),
        ),
        ListTile(leading: Icon(Icons.ad_units), title: Text('How to run ads')),
      ],
    );
  }
}

class _PartnerTicketsStub extends StatelessWidget {
  const _PartnerTicketsStub();
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.support_agent),
      title: const Text('Open Support Center'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner support coming soon')),
      ),
    );
  }
}
