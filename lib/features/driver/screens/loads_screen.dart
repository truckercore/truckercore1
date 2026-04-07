import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/active_load.dart';

final driversLoadsProvider = StreamProvider<List<ActiveLoad>>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    return Stream.value([]);
  }

  return supabase
      .from('loads')
      .stream(primaryKey: ['id'])
      .eq('driver_id', userId)
      .order('created_at')
      .map((data) => data.map((json) => ActiveLoad.fromJson(json)).toList());
});

class LoadsScreen extends ConsumerWidget {
  const LoadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadsAsync = ref.watch(driversLoadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loads'),
      ),
      body: loadsAsync.when(
        data: (loads) {
          if (loads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Loads',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You don't have any loads assigned",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driversLoadsProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: loads.length,
              itemBuilder: (context, index) {
                final load = loads[index];
                return _LoadCard(load: load);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(driversLoadsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadCard extends StatelessWidget {
  final ActiveLoad load;

  const _LoadCard({required this.load});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/driver/loads/${load.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Load #${load.loadNumber}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text(_getStatusDisplay(load.status)),
                    backgroundColor: _getStatusColor(load.status).withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: _getStatusColor(load.status),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      load.pickupLocation,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.flag, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      load.deliveryLocation,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              if (load.eta != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'ETA: ${_formatDateTime(load.eta!)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case 'in_transit':
        return 'In Transit';
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_transit':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
