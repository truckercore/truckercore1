import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/load.dart';
import '../services/load_service.dart';

class LoadBoardScreen extends ConsumerStatefulWidget {
  const LoadBoardScreen({super.key});

  @override
  ConsumerState<LoadBoardScreen> createState() => _LoadBoardScreenState();
}

class _LoadBoardScreenState extends ConsumerState<LoadBoardScreen> {
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final availableLoads = ref.watch(availableLoadsProvider);
    final activeLoads = ref.watch(myActiveLoadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Load Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/loads/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('Available', 'available'),
                ),
                Expanded(
                  child: _buildTabButton('My Loads', 'active'),
                ),
                Expanded(
                  child: _buildTabButton('History', 'history'),
                ),
              ],
            ),
          ),

          // Load List
          Expanded(
            child: _filterStatus == 'available'
                ? availableLoads.when(
                    data: (loads) => _buildLoadList(loads),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  )
                : _filterStatus == 'active'
                    ? activeLoads.when(
                        data: (loads) => _buildLoadList(loads),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Center(child: Text('Error: $e')),
                      )
                    : _buildHistoryView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/loads/create'),
        icon: const Icon(Icons.add),
        label: const Text('Post Load'),
      ),
    );
  }

  Widget _buildTabButton(String label, String status) {
    final isSelected = _filterStatus == status;
    return InkWell(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadList(List<Load> loads) {
    if (loads.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No loads found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(availableLoadsProvider);
        ref.invalidate(myActiveLoadsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: loads.length,
        itemBuilder: (context, index) {
          final load = loads[index];
          return _buildLoadCard(load);
        },
      ),
    );
  }

  Widget _buildLoadCard(Load load) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showLoadDetails(load),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    load.loadNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusChip(load.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${load.pickupLocation.city}, ${load.pickupLocation.state}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${load.deliveryLocation.city}, ${load.deliveryLocation.state}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip('${load.miles.toStringAsFixed(0)} mi', Icons.straighten),
                  _buildInfoChip('${load.weight.toStringAsFixed(0)} lbs', Icons.scale),
                  _buildInfoChip('\$${load.rate.toStringAsFixed(0)}', Icons.attach_money),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Pickup: ${_formatDate(load.pickupDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'Delivery: ${_formatDate(load.deliveryDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'available':
        color = Colors.green;
        label = 'Available';
        break;
      case 'assigned':
        color = Colors.blue;
        label = 'Assigned';
        break;
      case 'in_transit':
        color = Colors.orange;
        label = 'In Transit';
        break;
      case 'delivered':
        color = Colors.grey;
        label = 'Delivered';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return FutureBuilder(
      future: ref.read(loadServiceProvider).getLoadHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final loads = snapshot.data ?? [];
        return _buildLoadList(loads);
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _showLoadDetails(Load load) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                load.loadNumber,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildStatusChip(load.status),
              const SizedBox(height: 24),
              const Text(
                'Pickup Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(load.pickupLocation.name),
              Text(load.pickupLocation.address),
              Text('${load.pickupLocation.city}, ${load.pickupLocation.state} ${load.pickupLocation.zip}'),
              const SizedBox(height: 16),
              const Text(
                'Delivery Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(load.deliveryLocation.name),
              Text(load.deliveryLocation.address),
              Text('${load.deliveryLocation.city}, ${load.deliveryLocation.state} ${load.deliveryLocation.zip}'),
              const SizedBox(height: 16),
              const Text(
                'Load Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Distance', '${load.miles.toStringAsFixed(0)} miles'),
              _buildDetailRow('Weight', '${load.weight.toStringAsFixed(0)} lbs'),
              _buildDetailRow('Commodity', load.commodity),
              _buildDetailRow('Rate', '\$${load.rate.toStringAsFixed(2)}'),
              _buildDetailRow('Pickup Date', _formatDate(load.pickupDate)),
              _buildDetailRow('Delivery Date', _formatDate(load.deliveryDate)),
              if (load.specialInstructions != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Special Instructions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(load.specialInstructions!),
              ],
              const SizedBox(height: 24),
              if (load.status == 'available')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _acceptLoad(load),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Text('Accept Load'),
                  ),
                ),
              if (load.status == 'assigned')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startLoad(load),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Text('Start Trip'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Loads'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Origin State', border: OutlineInputBorder()),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Destination State', border: OutlineInputBorder()),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Min Rate', border: OutlineInputBorder(), prefixText: '\$'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptLoad(Load load) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Accept Load'),
            content: Text('Accept load ${load.loadNumber}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Accept'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      try {
        await ref.read(loadServiceProvider).assignLoad(
              loadId: load.id,
              driverId: 'current-driver-id', // TODO: replace with auth user id
              vehicleId: 'current-vehicle-id', // TODO: replace with selected vehicle id
            );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Load accepted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to accept load: $e')),
          );
        }
      }
    }
  }

  Future<void> _startLoad(Load load) async {
    try {
      await ref.read(loadServiceProvider).markPickedUp(load.id);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/navigation/active', arguments: load);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start load: $e')),
        );
      }
    }
  }
}
