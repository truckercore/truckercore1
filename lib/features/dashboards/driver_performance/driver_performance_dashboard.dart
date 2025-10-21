import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dashboards/base_dashboard.dart';
import '../models/dashboard_layout_config.dart';
import '../widgets/customize_layout_dialog.dart';

// Driver performance metrics
class DriverMetrics {
  final String driverId;
  final String driverName;
  final double safetyScore;
  final double fuelEfficiency; // MPG
  final double onTimeDeliveryPercent;
  final int totalTrips;
  final int totalMiles;
  final int hardBrakes;
  final int rapidAccelerations;
  final int speedingEvents;

  DriverMetrics({
    required this.driverId,
    required this.driverName,
    required this.safetyScore,
    required this.fuelEfficiency,
    required this.onTimeDeliveryPercent,
    required this.totalTrips,
    required this.totalMiles,
    required this.hardBrakes,
    required this.rapidAccelerations,
    required this.speedingEvents,
  });

  // Calculate overall performance score
  double get performanceScore {
    return (safetyScore * 0.4) +
        (fuelEfficiency / 15 * 100 * 0.3) + // Normalize MPG to 0-100
        (onTimeDeliveryPercent * 0.3);
  }
}

// Mock data provider - replace with real data from your backend
final driverMetricsProvider = Provider<List<DriverMetrics>>((ref) {
  // Synthetic driver list for demo/desktop testing without backend coupling.
  final names = <String>[
    'John Smith', 'Jane Doe', 'Mike Johnson', 'Sarah Williams', 'Tom Brown',
    'Emily Davis', 'Chris Miller', 'Laura Wilson', 'Daniel Anderson', 'Amy Thomas',
    'Kevin Moore', 'Olivia Taylor', 'Brian Jackson', 'Sophia Martin', 'Liam Lee',
  ];

  final list = names.map((name) {
    final h = name.hashCode;
    final safety = 70 + (h % 30).toDouble();
    final mpg = 6.0 + ((h >> 3) % 30) / 10.0;
    final onTime = 85 + ((h >> 5) % 15).toDouble();
    final trips = 120 + ((h >> 7) % 120);
    final miles = 20000 + ((h >> 9) % 20000);
    final hard = (h >> 2) % 20;
    final accel = (h >> 4) % 15;
    final speed = (h >> 6) % 10;

    return DriverMetrics(
      driverId: 'drv_${h.abs()}',
      driverName: name,
      safetyScore: safety,
      fuelEfficiency: mpg,
      onTimeDeliveryPercent: onTime,
      totalTrips: trips,
      totalMiles: miles,
      hardBrakes: hard,
      rapidAccelerations: accel,
      speedingEvents: speed,
    );
  }).toList();

  list.sort((a, b) => b.performanceScore.compareTo(a.performanceScore));
  return list;
});

class DriverPerformanceDashboard extends BaseDashboard {
  const DriverPerformanceDashboard({super.key})
      : super(
          config: const DashboardConfig(
            id: 'driver_performance',
            title: 'Driver Performance Dashboard',
            defaultSize: Size(1400, 900),
          ),
        );

  @override
  ConsumerState<DriverPerformanceDashboard> createState() =>
      _DriverPerformanceDashboardState();

  @override
  Widget buildDashboard(BuildContext context, WidgetRef ref) {
    final drivers = ref.watch(driverMetricsProvider);

    if (drivers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No driver data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return _DriverPerformanceContent(drivers: drivers);
  }

  @override
  Future<void> onDashboardInit(WidgetRef ref) async {
    debugPrint('Driver Performance Dashboard initialized');
  }
}

class _DriverPerformanceDashboardState
    extends BaseDashboardState<DriverPerformanceDashboard> {}

class _DriverPerformanceContent extends StatefulWidget {
  final List<DriverMetrics> drivers;

  const _DriverPerformanceContent({required this.drivers});

  @override
  State<_DriverPerformanceContent> createState() =>
      _DriverPerformanceContentState();
}

class _DriverPerformanceContentState extends State<_DriverPerformanceContent> {
  String _selectedMetric = 'performance';
  String _sortBy = 'performance';
  bool _sortDescending = true;
  DashboardLayoutConfig _layout = const DashboardLayoutConfig();

  @override
  void initState() {
    super.initState();
    // Load saved layout and apply initial sort
    () async {
      final cfg = await DashboardLayoutConfig.load('driver_performance');
      if (mounted) {
        setState(() {
          _layout = cfg;
          _selectedMetric = cfg.sortBy;
          _sortBy = cfg.sortBy;
        });
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final sortedDrivers = _sortDrivers(widget.drivers);
    final topDrivers = sortedDrivers.take(10).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with filters
          _buildHeader(context),
          const SizedBox(height: 24),

          // KPI Summary Cards
          _buildKPICards(context, sortedDrivers),
          const SizedBox(height: 24),

          // Main Content
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leaderboard
                Expanded(
                  flex: 2,
                  child: _buildLeaderboard(context, topDrivers),
                ),
                const SizedBox(width: 16),
                // Detailed metrics
                Expanded(
                  flex: 3,
                  child: _buildDetailedMetrics(context, sortedDrivers),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          'Performance Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Customize',
          icon: const Icon(Icons.tune),
          onPressed: _openCustomize,
        ),
        // Metric selector
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'performance',
              label: Text('Overall'),
              icon: Icon(Icons.assessment, size: 16),
            ),
            ButtonSegment(
              value: 'safety',
              label: Text('Safety'),
              icon: Icon(Icons.shield, size: 16),
            ),
            ButtonSegment(
              value: 'fuel',
              label: Text('Fuel'),
              icon: Icon(Icons.local_gas_station, size: 16),
            ),
            ButtonSegment(
              value: 'ontime',
              label: Text('On-Time'),
              icon: Icon(Icons.schedule, size: 16),
            ),
          ],
          selected: {_selectedMetric},
          onSelectionChanged: (Set<String> selected) {
            setState(() {
              _selectedMetric = selected.first;
              _sortBy = selected.first;
              _layout = _layout.copyWith(sortBy: _sortBy);
            });
          },
        ),
      ],
    );
  }

  Widget _buildKPICards(BuildContext context, List<DriverMetrics> drivers) {
    final avgSafety = drivers.fold<double>(0, (sum, d) => sum + d.safetyScore) / drivers.length;
    final avgFuel = drivers.fold<double>(0, (sum, d) => sum + d.fuelEfficiency) / drivers.length;
    final avgOnTime = drivers.fold<double>(0, (sum, d) => sum + d.onTimeDeliveryPercent) / drivers.length;

    return Row(
      children: [
        Expanded(
          child: _buildKPICard(
            context,
            'Avg Safety Score',
            avgSafety.toStringAsFixed(1),
            _getScoreColor(avgSafety),
            Icons.shield,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKPICard(
            context,
            'Avg Fuel Efficiency',
            '${avgFuel.toStringAsFixed(1)} MPG',
            Colors.blue,
            Icons.local_gas_station,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKPICard(
            context,
            'Avg On-Time %',
            '${avgOnTime.toStringAsFixed(0)}%',
            _getScoreColor(avgOnTime),
            Icons.schedule,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildKPICard(
            context,
            'Total Drivers',
            drivers.length.toString(),
            Colors.purple,
            Icons.people,
          ),
        ),
      ],
    );
  }

  Widget _buildKPICard(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
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
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(BuildContext context, List<DriverMetrics> topDrivers) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Top 10 Leaderboard',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: topDrivers.length,
              itemBuilder: (context, index) {
                final driver = topDrivers[index];
                final rank = index + 1;
                final score = _getDriverScore(driver);

                return ListTile(
                  leading: _buildRankBadge(rank),
                  title: Text(driver.driverName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${driver.totalTrips} trips'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        score.toStringAsFixed(1),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _getScoreColor(score)),
                      ),
                      Text(
                        _getMetricLabel(),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color;
    IconData? icon;

    if (rank == 1) {
      color = Colors.amber;
      icon = Icons.emoji_events;
    } else if (rank == 2) {
      color = Colors.grey[400]!;
      icon = Icons.emoji_events;
    } else if (rank == 3) {
      color = Colors.brown;
      icon = Icons.emoji_events;
    } else {
      color = Colors.grey[700]!;
      icon = null;
    }

    return CircleAvatar(
      backgroundColor: color,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: 20)
          : Text(
              rank.toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildDetailedMetrics(BuildContext context, List<DriverMetrics> drivers) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Detailed Metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 24,
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  columns: _buildColumns(),
                  rows: drivers.map((d) => DataRow(cells: _buildCells(d))).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DriverMetrics> _sortDrivers(List<DriverMetrics> drivers) {
    final sorted = List<DriverMetrics>.from(drivers);

    sorted.sort((a, b) {
      int compare;
      switch (_sortBy) {
        case 'name':
          compare = a.driverName.compareTo(b.driverName);
          break;
        case 'safety':
          compare = a.safetyScore.compareTo(b.safetyScore);
          break;
        case 'fuel':
          compare = a.fuelEfficiency.compareTo(b.fuelEfficiency);
          break;
        case 'ontime':
          compare = a.onTimeDeliveryPercent.compareTo(b.onTimeDeliveryPercent);
          break;
        case 'trips':
          compare = a.totalTrips.compareTo(b.totalTrips);
          break;
        case 'miles':
          compare = a.totalMiles.compareTo(b.totalMiles);
          break;
        case 'performance':
        default:
          compare = a.performanceScore.compareTo(b.performanceScore);
      }

      return _sortDescending ? -compare : compare;
    });

    return sorted;
  }

  void _toggleSort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortDescending = !_sortDescending;
      } else {
        _sortBy = field;
        _sortDescending = true;
      }
    });
  }

  double _getDriverScore(DriverMetrics driver) {
    switch (_selectedMetric) {
      case 'safety':
        return driver.safetyScore;
      case 'fuel':
        return driver.fuelEfficiency;
      case 'ontime':
        return driver.onTimeDeliveryPercent;
      case 'performance':
      default:
        return driver.performanceScore;
    }
  }

  String _getMetricLabel() {
    switch (_selectedMetric) {
      case 'safety':
        return 'score';
      case 'fuel':
        return 'MPG';
      case 'ontime':
        return '%';
      case 'performance':
      default:
        return 'score';
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  List<DataColumn> _buildColumns() {
    final cols = <DataColumn>[
      const DataColumn(label: Text('Driver')),
    ];
    if (_layout.visibleMetrics.contains('safety')) {
      cols.add(DataColumn(label: const Text('Safety'), numeric: true, onSort: (_, __) => _toggleSort('safety')));
    }
    if (_layout.visibleMetrics.contains('fuel')) {
      cols.add(DataColumn(label: const Text('Fuel (MPG)'), numeric: true, onSort: (_, __) => _toggleSort('fuel')));
    }
    if (_layout.visibleMetrics.contains('ontime')) {
      cols.add(DataColumn(label: const Text('On-Time %'), numeric: true, onSort: (_, __) => _toggleSort('ontime')));
    }
    cols.addAll([
      DataColumn(label: const Text('Trips'), numeric: true, onSort: (_, __) => _toggleSort('trips')),
      DataColumn(label: const Text('Miles'), numeric: true, onSort: (_, __) => _toggleSort('miles')),
      const DataColumn(label: Text('Events'), numeric: true, tooltip: 'Hard brakes + Rapid accel. + Speeding'),
    ]);
    return cols;
  }

  List<DataCell> _buildCells(DriverMetrics driver) {
    final totalEvents = driver.hardBrakes + driver.rapidAccelerations + driver.speedingEvents;
    final cells = <DataCell>[
      DataCell(Text(driver.driverName)),
    ];
    if (_layout.visibleMetrics.contains('safety')) {
      cells.add(DataCell(Text(
        driver.safetyScore.toStringAsFixed(1),
        style: TextStyle(color: _getScoreColor(driver.safetyScore), fontWeight: FontWeight.w600),
      )));
    }
    if (_layout.visibleMetrics.contains('fuel')) {
      cells.add(DataCell(Text(driver.fuelEfficiency.toStringAsFixed(1))));
    }
    if (_layout.visibleMetrics.contains('ontime')) {
      cells.add(DataCell(Text(
        '${driver.onTimeDeliveryPercent.toStringAsFixed(0)}%',
        style: TextStyle(color: _getScoreColor(driver.onTimeDeliveryPercent), fontWeight: FontWeight.w600),
      )));
    }
    cells.addAll([
      DataCell(Text(driver.totalTrips.toString())),
      DataCell(Text('${(driver.totalMiles / 1000).toStringAsFixed(1)}K')),
      DataCell(Text(
        totalEvents.toString(),
        style: TextStyle(
          color: totalEvents > 20
              ? Colors.red
              : totalEvents > 10
                  ? Colors.orange
                  : Colors.green,
          fontWeight: FontWeight.w600,
        ),
      )),
    ]);
    return cells;
  }

  Future<void> _openCustomize() async {
    final newCfg = await showDialog<DashboardLayoutConfig>(
      context: context,
      builder: (ctx) => CustomizeLayoutDialog(currentConfig: _layout, onSave: (c) => Navigator.of(ctx).pop(c)),
    );
    if (newCfg != null) {
      await newCfg.save('driver_performance');
      if (mounted) {
        setState(() {
          _layout = newCfg;
          _selectedMetric = newCfg.sortBy;
          _sortBy = newCfg.sortBy;
        });
      }
    }
  }
}
