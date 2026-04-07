import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/services/truck_stop_services.dart';
import '../../common/state/session_provider.dart';

class TruckStopDealsBanner extends ConsumerWidget {
  const TruckStopDealsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session.isPremium) {
      return const SizedBox.shrink(); // show to non-premium only
    }

    return FutureBuilder<List<TruckStopDeal>>(
      future: ref.read(truckStopServiceProvider).fetchActiveDeals(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: ListTile(
                title: const Text('Deals'),
                subtitle: Text('Error loading deals: ${snap.error}'),
                trailing: TextButton(
                  onPressed: () => context.push('/truck-stops'),
                  child: const Text('Open'),
                ),
              ),
            ),
          );
        }
        final deals = (snap.data ?? const <TruckStopDeal>[])
            .where((d) => d.isActive)
            .toList();
        if (deals.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: ListTile(
                title: const Text('Truck Stop Deals'),
                subtitle: const Text(
                  'No active deals right now. Check Truck Stops.',
                ),
                trailing: TextButton(
                  onPressed: () => context.push('/truck-stops'),
                  child: const Text('See all'),
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/truck-stops'), // entire banner tappable
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Truck Stop Deals',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final d in deals.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '• ${d.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/truck-stops'),
                        child: const Text('See all'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
