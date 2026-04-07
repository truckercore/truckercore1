import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poi_models.dart';
import '../services/poi_service.dart';

class FindParkingScreen extends ConsumerStatefulWidget {
  const FindParkingScreen({super.key});

  @override
  ConsumerState<FindParkingScreen> createState() => _FindParkingScreenState();
}

class _FindParkingScreenState extends ConsumerState<FindParkingScreen> {
  List<TruckStop>? _truckStops;
  bool _isLoading = false;
  bool _parkingOnlyFilter = true;
  double _radiusMiles = 50;

  @override
  void initState() {
    super.initState();
    _loadNearbyTruckStops();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Parking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyTruckStops,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Parking Available Only'),
                        value: _parkingOnlyFilter,
                        onChanged: (value) {
                          setState(() => _parkingOnlyFilter = value ?? true);
                          _loadNearbyTruckStops();
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Radius: '),
                    Expanded(
                      child: Slider(
                        value: _radiusMiles,
                        min: 10,
                        max: 100,
                        divisions: 9,
                        label: '${_radiusMiles.toInt()} mi',
                        onChanged: (value) {
                          setState(() => _radiusMiles = value);
                        },
                        onChangeEnd: (value) => _loadNearbyTruckStops(),
                      ),
                    ),
                    Text('${_radiusMiles.toInt()} mi'),
                  ],
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _truckStops == null || _truckStops!.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_parking, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No truck stops found nearby',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _truckStops!.length,
                        itemBuilder: (context, index) {
                          final stop = _truckStops![index];
                          return _buildTruckStopCard(stop);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckStopCard(TruckStop stop) {
    final hasParking = (stop.availableSpaces ?? 0) > 0;
    final parkingColor = hasParking ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTruckStopDetails(stop),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stop.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: parkingColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: parkingColor),
                    ),
                    child: Text(
                      (stop.availableSpaces != null) ? '${stop.availableSpaces}' : 'N/A',
                      style: TextStyle(
                        color: parkingColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Distance: ${_calculateDistance(stop.lat, stop.lng).toStringAsFixed(1)} mi',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateDistance(double lat, double lng) {
    // Mock calculation - in real app would use current location
    return 25.5;
  }

  Future<void> _loadNearbyTruckStops() async {
    setState(() => _isLoading = true);

    try {
      final poiService = ref.read(poiServiceProvider);

      // Mock current location - in real app would use location service
      final stops = await poiService.findNearbyTruckStops(
        lat: 40.7128,
        lng: -74.0060,
        radiusMiles: _radiusMiles,
        parkingAvailable: _parkingOnlyFilter,
      );

      if (!mounted) return;
      setState(() {
        _truckStops = stops;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load truck stops: $e')),
      );
    }
  }

  void _showTruckStopDetails(TruckStop stop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                stop.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Available Spaces', (stop.availableSpaces != null) ? '${stop.availableSpaces}' : 'N/A'),
              _buildDetailRow('Distance', '${_calculateDistance(stop.lat, stop.lng).toStringAsFixed(1)} mi'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to this location
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate Here'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Call truck stop (placeholder)
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
