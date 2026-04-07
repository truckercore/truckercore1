import 'package:flutter/material.dart';
import '../models/vehicle_models.dart';

class VehicleListView extends StatelessWidget {
  final List<VehicleStatus> vehicles;

  const VehicleListView({super.key, required this.vehicles});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        return _VehicleListTile(vehicle: vehicle);
      },
    );
  }
}

class _VehicleListTile extends StatelessWidget {
  final VehicleStatus vehicle;

  const _VehicleListTile({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(vehicle.active ? 'active' : 'offline').withValues(alpha: 0.2),
          child: Icon(
            Icons.local_shipping,
            color: _getStatusColor(vehicle.active ? 'active' : 'offline'),
          ),
        ),
        title: Text(
          vehicle.vehicleId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Lat: ${vehicle.lat.toStringAsFixed(4)}, Lng: ${vehicle.lng.toStringAsFixed(4)}'),
            Text('Updated: ${vehicle.updatedAt ?? DateTime.now()}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(_getStatusText(vehicle.active ? 'active' : 'offline')),
              backgroundColor: _getStatusColor(vehicle.active ? 'active' : 'offline').withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: _getStatusColor(vehicle.active ? 'active' : 'offline'),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        onTap: () => _showVehicleDetails(context, vehicle),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'driving':
        return Colors.green;
      case 'idle':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    return status.toUpperCase();
  }

  void _showVehicleDetails(BuildContext context, VehicleStatus vehicle) {
    Navigator.pushNamed(
      context,
      '/fleet/vehicle-details',
      arguments: vehicle,
    );
  }
}
