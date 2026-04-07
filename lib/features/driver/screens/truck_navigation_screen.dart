import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/route_result.dart';
import '../../../core/models/vehicle_dimensions.dart';
import '../services/truck_routing_service.dart';

class TruckNavigationScreen extends ConsumerStatefulWidget {
  const TruckNavigationScreen({super.key});

  @override
  ConsumerState<TruckNavigationScreen> createState() => _TruckNavigationScreenState();
}

class _TruckNavigationScreenState extends ConsumerState<TruckNavigationScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  bool _includeTraffic = true;
  bool _includeWeather = true;
  RouteResult? _currentRoute;
  bool _isCalculating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truck Navigation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showVehicleSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Route Input
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                TextField(
                  controller: _originController,
                  decoration: InputDecoration(
                    labelText: 'Starting Location',
                    prefixIcon: const Icon(Icons.my_location),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.gps_fixed),
                      onPressed: _useCurrentLocation,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Traffic'),
                        value: _includeTraffic,
                        onChanged: (value) => setState(() => _includeTraffic = value ?? true),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Weather'),
                        value: _includeWeather,
                        onChanged: (value) => setState(() => _includeWeather = value ?? true),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCalculating ? null : _calculateRoute,
                    icon: _isCalculating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.route),
                    label: Text(_isCalculating ? 'Calculating...' : 'Calculate Route'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Route Details
          if (_currentRoute != null)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildRouteOverview(_currentRoute!),
                  const SizedBox(height: 16),
                  if (_currentRoute!.restrictions.isNotEmpty)
                    _buildRestrictionsCard(_currentRoute!.restrictions),
                  const SizedBox(height: 16),
                  if (_currentRoute!.trafficIncidents.isNotEmpty)
                    _buildTrafficCard(_currentRoute!.trafficIncidents),
                  const SizedBox(height: 16),
                  if (_currentRoute!.weatherAlerts.isNotEmpty)
                    _buildWeatherCard(_currentRoute!.weatherAlerts),
                ],
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.route, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Enter origin and destination\nto calculate truck-safe route',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteOverview(RouteResult route) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Distance',
                    '${route.distanceMiles.toStringAsFixed(1)} mi',
                    Icons.straighten,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Duration',
                    '${(route.durationMinutes / 60).toStringAsFixed(1)} hrs',
                    Icons.schedule,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startNavigation(route),
                icon: const Icon(Icons.navigation),
                label: const Text('Start Navigation'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRestrictionsCard(List<RouteRestriction> restrictions) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Route Restrictions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...restrictions.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${r.description}${r.limit != null ? ' - ${r.limit}' : ''}'),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficCard(List<TrafficIncident> incidents) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.traffic, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Traffic Incidents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...incidents.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${i.description} (+${i.delayMinutes} min)'),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard(List<WeatherAlert> alerts) {
    return Card(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Weather Alerts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: a.severity == 'severe' ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(a.description)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _useCurrentLocation() {
    // Implement current location fetch
    _originController.text = 'Current Location';
  }

  Future<void> _calculateRoute() async {
    if (_originController.text.isEmpty || _destinationController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter origin and destination')),
      );
      return;
    }

    setState(() => _isCalculating = true);

    try {
      final routingService = ref.read(truckRoutingServiceProvider);

      // In a real app, you would geocode the addresses first
      final route = await routingService.calculateRoute(
        startLat: 40.7128,
        startLng: -74.0060,
        endLat: 34.0522,
        endLng: -118.2437,
        dimensions: const VehicleDimensions(
          heightFeet: 13.5,
          widthFeet: 8.5,
          lengthFeet: 53,
          weightLbs: 80000,
          axles: 5,
        ),
        includeTraffic: _includeTraffic,
        includeWeather: _includeWeather,
      );

      if (!mounted) return;
      setState(() {
        _currentRoute = route;
        _isCalculating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCalculating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to calculate route: $e')),
      );
    }
  }

  void _startNavigation(RouteResult route) {
    Navigator.pushNamed(context, '/navigation/active', arguments: route);
  }

  void _showVehicleSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.height),
              title: Text('Height: 13\'6"'),
              trailing: Icon(Icons.edit),
            ),
            ListTile(
              leading: Icon(Icons.straighten),
              title: Text('Length: 53\''),
              trailing: Icon(Icons.edit),
            ),
            ListTile(
              leading: Icon(Icons.scale),
              title: Text('Weight: 80,000 lbs'),
              trailing: Icon(Icons.edit),
            ),
            ListTile(
              leading: Icon(Icons.dangerous),
              title: Text('Hazmat: None'),
              trailing: Icon(Icons.edit),
            ),
          ],
        ),
      ),
    );
  }
}
