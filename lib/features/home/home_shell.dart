import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roadside Providers')),
      body: Row(children: [
        NavigationRail(
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.assignment), label: Text('Jobs')),
            NavigationRailDestination(icon: Icon(Icons.design_services), label: Text('Services')),
            NavigationRailDestination(icon: Icon(Icons.map), label: Text('Coverage')),
            NavigationRailDestination(icon: Icon(Icons.price_change), label: Text('Pricing')),
            NavigationRailDestination(icon: Icon(Icons.local_shipping), label: Text('Dispatch')),
            NavigationRailDestination(icon: Icon(Icons.payments), label: Text('Payouts')),
            NavigationRailDestination(icon: Icon(Icons.analytics), label: Text('Analytics')),
            NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
          ],
          selectedIndex: _indexForLocation(GoRouterState.of(context).uri.toString()),
          onDestinationSelected: (i) {
            const paths = ['/jobs','/services','/coverage','/pricing','/dispatch','/payouts','/analytics','/settings'];
            context.go(paths[i]);
          },
        ),
        const VerticalDivider(width: 1),
        Expanded(child: child),
      ]),
    );
  }

  int _indexForLocation(String loc) {
    if (loc.startsWith('/services')) return 1;
    if (loc.startsWith('/coverage')) return 2;
    if (loc.startsWith('/pricing')) return 3;
    if (loc.startsWith('/dispatch')) return 4;
    if (loc.startsWith('/payouts')) return 5;
    if (loc.startsWith('/analytics')) return 6;
    if (loc.startsWith('/settings')) return 7;
    return 0;
  }
}
