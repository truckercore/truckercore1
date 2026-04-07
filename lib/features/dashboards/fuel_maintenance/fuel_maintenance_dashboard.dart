import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dashboards/base_dashboard.dart';

// Fuel & Maintenance data models
class FuelRecord {
  final String vehicleId;
  final String unitNumber;
  final DateTime date;
  final double gallons;
  final double costPerGallon;
  final double totalCost;
  final double odometer;

  FuelRecord({
    required this.vehicleId,
    required this.unitNumber,
    required this.date,
    required this.gallons,
    required this.costPerGallon,
    required this.totalCost,
    required this.odometer,
  });

  double get mpg {
    // Simplified calculation - in reality, calculate from distance
    return 6.5 + (unitNumber.hashCode % 30) / 10;
  }
}

class MaintenanceRecord {
  final String vehicleId;
  final String unitNumber;
  final DateTime date;
  final String type;
  final String description;
  final double cost;
  final int odometerAtService;
  final String? vendor;
  final bool isScheduled;

  MaintenanceRecord({
    required this.vehicleId,
    required this.unitNumber,
    required this.date,
    required this.type,
    required this.description,
    required this.cost,
    required this.odometerAtService,
    this.vendor,
    this.isScheduled = false,
  });
}

// Mock data providers
final fuelRecordsProvider = Provider<List<FuelRecord>>((ref) {
  // Generate synthetic fuel records for a small fleet when backend data isn't wired.
  final now = DateTime.now();
  final units = List.generate(10, (i) => 'TRUCK-${(i + 1).toString().padLeft(3, '0')}');

  return units.expand((unit) {
    return List.generate(5, (i) {
      final daysAgo = i * 7;
      final gallons = (120 + (unit.hashCode % 30)).toDouble();
      final cpg = 3.5 + (i * 0.1);
      return FuelRecord(
        vehicleId: 'veh_${unit.hashCode}',
        unitNumber: unit,
        date: now.subtract(Duration(days: daysAgo)),
        gallons: gallons,
        costPerGallon: cpg,
        totalCost: gallons * cpg,
        odometer: (25000 + (daysAgo * 500)).toDouble(),
      );
    });
  }).toList();
});

final maintenanceRecordsProvider = Provider<List<MaintenanceRecord>>((ref) {
  final now = DateTime.now();
  final units = List.generate(10, (i) => 'TRUCK-${(i + 1).toString().padLeft(3, '0')}');

  final maintenanceTypes = <(String, double, bool)>[
    ('Oil Change', 150.0, true),
    ('Tire Rotation', 100.0, true),
    ('Brake Inspection', 200.0, true),
    ('Engine Repair', 1500.0, false),
    ('Transmission Service', 800.0, false),
  ];

  return units.expand((unit) {
    return List.generate(3, (i) {
      final type = maintenanceTypes[i % maintenanceTypes.length];
      return MaintenanceRecord(
        vehicleId: 'veh_${unit.hashCode}',
        unitNumber: unit,
        date: now.subtract(Duration(days: i * 30)),
        type: type.$1,
        description: 'Routine ${type.$1.toLowerCase()}',
        cost: type.$2 + (unit.hashCode % 100),
        odometerAtService: 25000 - (i * 5000),
        vendor: 'Service Center ${i + 1}',
        isScheduled: type.$3,
      );
    });
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

class FuelMaintenanceDashboard extends BaseDashboard {
  const FuelMaintenanceDashboard({super.key})
      : super(
          config: const DashboardConfig(
            id: 'fuel_maintenance',
            title: 'Fuel & Maintenance Dashboard',
            defaultSize: Size(1400, 900),
          ),
        );

  @override
  ConsumerState<FuelMaintenanceDashboard> createState() =>
      _FuelMaintenanceDashboardState();

  @override
  Widget buildDashboard(BuildContext context, WidgetRef ref) {
    final fuelRecords = ref.watch(fuelRecordsProvider);
    final maintenanceRecords = ref.watch(maintenanceRecordsProvider);

    return _FuelMaintenanceContent(
      fuelRecords: fuelRecords,
      maintenanceRecords: maintenanceRecords,
    );
  }
}

class _FuelMaintenanceDashboardState
    extends BaseDashboardState<FuelMaintenanceDashboard> {}

class _FuelMaintenanceContent extends StatefulWidget {
  final List<FuelRecord> fuelRecords;
  final List<MaintenanceRecord> maintenanceRecords;

  const _FuelMaintenanceContent({
    required this.fuelRecords,
    required this.maintenanceRecords,
  });

  @override
  State<_FuelMaintenanceContent> createState() =>
      _FuelMaintenanceContentState();
}

class _FuelMaintenanceContentState extends State<_FuelMaintenanceContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.local_gas_station), text: 'Fuel'),
              Tab(icon: Icon(Icons.build), text: 'Maintenance'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFuelTab(),
              _buildMaintenanceTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFuelTab() {
    final totalCost = widget.fuelRecords.fold<double>(0, (sum, r) => sum + r.totalCost);
    final totalGallons = widget.fuelRecords.fold<double>(0, (sum, r) => sum + r.gallons);
    final avgMpg = widget.fuelRecords.fold<double>(0, (sum, r) => sum + r.mpg) / (widget.fuelRecords.isEmpty ? 1 : widget.fuelRecords.length);
    final avgCostPerGallon = totalGallons == 0 ? 0 : totalCost / totalGallons;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildKPICard('Total Fuel Cost', '\$${totalCost.toStringAsFixed(2)}', Colors.red, Icons.attach_money),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard('Total Gallons', totalGallons.toStringAsFixed(0), Colors.blue, Icons.local_gas_station),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard('Avg MPG', avgMpg.toStringAsFixed(1), Colors.green, Icons.speed),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard('Avg \$/Gal', '\$${avgCostPerGallon.toStringAsFixed(2)}', Colors.orange, Icons.trending_up),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Fuel Records Table
          Expanded(
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.local_gas_station),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Fuel Transactions',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () {
                            // Export to CSV (placeholder)
                          },
                          tooltip: 'Export to CSV',
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Vehicle')),
                            DataColumn(label: Text('Gallons'), numeric: true),
                            DataColumn(label: Text('\$/Gal'), numeric: true),
                            DataColumn(label: Text('Total'), numeric: true),
                            DataColumn(label: Text('MPG'), numeric: true),
                            DataColumn(label: Text('Odometer'), numeric: true),
                          ],
                          rows: widget.fuelRecords.take(20).map((record) {
                            return DataRow(
                              cells: [
                                DataCell(Text('${record.date.month}/${record.date.day}/${record.date.year}')),
                                DataCell(Text(record.unitNumber)),
                                DataCell(Text(record.gallons.toStringAsFixed(1))),
                                DataCell(Text('\$${record.costPerGallon.toStringAsFixed(2)}')), 
                                DataCell(Text('\$${record.totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(record.mpg.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: record.mpg >= 7
                                          ? Colors.green
                                          : record.mpg >= 6
                                              ? Colors.orange
                                              : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ))),
                                DataCell(Text('${(record.odometer / 1000).toStringAsFixed(0)}K')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    final totalCost = widget.maintenanceRecords.fold<double>(0, (sum, r) => sum + r.cost);
    final scheduledCount = widget.maintenanceRecords.where((r) => r.isScheduled).length;
    final unscheduledCount = widget.maintenanceRecords.length - scheduledCount;

    // Group by type
    final costByType = <String, double>{};
    for (final record in widget.maintenanceRecords) {
      costByType[record.type] = (costByType[record.type] ?? 0) + record.cost;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildKPICard('Total Maintenance Cost', '\$${totalCost.toStringAsFixed(2)}', Colors.red, Icons.attach_money),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard('Scheduled Services', scheduledCount.toString(), Colors.green, Icons.schedule),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard('Unscheduled Repairs', unscheduledCount.toString(), Colors.orange, Icons.warning),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard('Total Records', widget.maintenanceRecords.length.toString(), Colors.blue, Icons.list),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Maintenance Records and Cost by Type
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Records Table
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.build),
                              const SizedBox(width: 8),
                              Text(
                                'Maintenance History',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () {
                                  // Export to CSV (placeholder)
                                },
                                tooltip: 'Export to CSV',
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.maintenanceRecords.length,
                            itemBuilder: (context, index) {
                              final record = widget.maintenanceRecords[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: record.isScheduled ? Colors.green : Colors.orange,
                                  child: Icon(record.isScheduled ? Icons.check_circle : Icons.warning, color: Colors.white, size: 20),
                                ),
                                title: Text(
                                  '${record.unitNumber} - ${record.type}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(record.description),
                                    Text(
                                      '${record.date.month}/${record.date.day}/${record.date.year} • ${(record.odometerAtService / 1000).toStringAsFixed(0)}K mi',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                    if (record.vendor != null)
                                      Text(
                                        record.vendor!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  '\$${record.cost.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Cost by Type
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cost by Service Type',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              children: costByType.entries.map((entry) {
                                final percentage = totalCost == 0 ? 0 : (entry.value / totalCost * 100);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text('\$${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)), 
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: (percentage / 100).clamp(0.0, 1.0),
                                        backgroundColor: Colors.grey[800],
                                        minHeight: 8,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${percentage.toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String label, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(
                  value,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
