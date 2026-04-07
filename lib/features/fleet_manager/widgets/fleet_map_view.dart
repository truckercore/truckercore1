import 'package:flutter/material.dart';
import '../models/vehicle_models.dart';

class FleetMapView extends StatelessWidget {
  final List<VehicleStatus> vehicles;
  const FleetMapView({super.key, required this.vehicles});

  @override
  Widget build(BuildContext context) {
    // Placeholder map view: shows pins as a simple grid/list until a real map is integrated.
    if (vehicles.isEmpty) {
      return const Center(
        child: Text('No active vehicles'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vehicles.length,
      itemBuilder: (context, index) {
        final v = vehicles[index];
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.blue),
          title: Text(v.vehicleId),
          subtitle: Text('Lat: ${v.lat.toStringAsFixed(4)}, Lng: ${v.lng.toStringAsFixed(4)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/fleet/vehicle-details', arguments: v),
        );
      },
    );
  }
}
