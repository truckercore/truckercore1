import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/load.dart';
import '../providers/load_provider.dart';
import '../widgets/load_card.dart';

class LoadsScreen extends ConsumerStatefulWidget {
  const LoadsScreen({super.key});

  @override
  ConsumerState<LoadsScreen> createState() => _LoadsScreenState();
}

class _LoadsScreenState extends ConsumerState<LoadsScreen> {
  LoadStatus? _filterStatus;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final loadsAsync = ref.watch(loadNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(loadNotifierProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: loadsAsync.when(
              data: (loads) {
                final filteredLoads = _filterLoads(loads);

                if (filteredLoads.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(loadNotifierProvider.notifier).refresh();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredLoads.length,
                    itemBuilder: (context, index) {
                      return LoadCard(load: filteredLoads[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(loadNotifierProvider.notifier).refresh();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to load posting screen
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search loads...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('Posted', LoadStatus.posted),
                const SizedBox(width: 8),
                _buildFilterChip('Assigned', LoadStatus.assigned),
                const SizedBox(width: 8),
                _buildFilterChip('In Transit', LoadStatus.inTransit),
                const SizedBox(width: 8),
                _buildFilterChip('Delivered', LoadStatus.delivered),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LoadStatus? status) {
    final isSelected = _filterStatus == status;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? status : null;
        });
      },
    );
  }

  List<Load> _filterLoads(List<Load> loads) {
    var filtered = loads;

    if (_filterStatus != null) {
      filtered = filtered.where((load) => load.status == _filterStatus).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((load) {
        final query = _searchQuery.toLowerCase();
        return load.loadNumber.toLowerCase().contains(query) ||
            load.origin.city.toLowerCase().contains(query) ||
            load.destination.city.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Widget _buildEmptyState() {
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
            'No loads found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
