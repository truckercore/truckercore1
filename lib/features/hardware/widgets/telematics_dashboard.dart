import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/telematics_data.dart';
import '../services/mock_telematics_service.dart';

class TelematicsDashboard extends ConsumerWidget {
  final String vehicleId;

  const TelematicsDashboard({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telematicsService = ref.watch(mockTelematicsServiceProvider);

    return StreamBuilder<TelematicsData>(
      stream: telematicsService.streamVehicleData(vehicleId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Speed & RPM
            Row(
              children: [
                Expanded(
                  child: _buildGaugeCard(
                    'Speed',
                    data.speed.toStringAsFixed(0),
                    'MPH',
                    Colors.blue,
                    data.speed / 80,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGaugeCard(
                    'RPM',
                    data.engineRpm.toString(),
                    'RPM',
                    Colors.orange,
                    data.engineRpm / 2000,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Engine Metrics
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Engine Metrics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildMetricRow(
                      'Temperature',
                      '${data.engineTemperature}°F',
                      Icons.thermostat,
                      data.engineTemperature > 220 ? Colors.red : Colors.green,
                    ),
                    _buildMetricRow(
                      'Oil Pressure',
                      '${data.oilPressure} PSI',
                      Icons.oil_barrel,
                      data.oilPressure < 20 ? Colors.red : Colors.green,
                    ),
                    _buildMetricRow(
                      'Battery',
                      '${data.batteryVoltage.toStringAsFixed(1)}V',
                      Icons.battery_charging_full,
                      data.batteryVoltage < 12.0 ? Colors.orange : Colors.green,
                    ),
                    _buildMetricRow(
                      'Fuel Level',
                      '${data.fuelLevel.toStringAsFixed(0)}%',
                      Icons.local_gas_station,
                      data.fuelLevel < 25 ? Colors.orange : Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tire Pressures
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tire Pressures',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTireIndicator('FL', data.tirePressures.frontLeft),
                        _buildTireIndicator('FR', data.tirePressures.frontRight),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTireIndicator('RL', data.tirePressures.rearLeft),
                        _buildTireIndicator('RR', data.tirePressures.rearRight),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recent Events
            if (data.events.isNotEmpty)
              Card(
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
                            'Recent Events',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...data.events.map((event) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _getEventIcon(event.type),
                                  size: 20,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(_getEventName(event.type)),
                                const Spacer(),
                                Text(
                                  'Severity: ${(event.severity * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),

            // Diagnostic Codes
            if (data.diagnosticCodes.isNotEmpty)
              Card(
                color: Colors.red.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Diagnostic Trouble Codes',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...data.diagnosticCodes.map((code) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.build, size: 20, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGaugeCard(
    String label,
    String value,
    String unit,
    Color color,
    double percentage,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    value: percentage.clamp(0.0, 1.0),
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          unit,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTireIndicator(String position, int pressure) {
    final isLow = pressure < 95;
    final color = isLow ? Colors.red : Colors.green;

    return Column(
      children: [
        Icon(Icons.circle, size: 60, color: color.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text(
          position,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          '$pressure PSI',
          style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  IconData _getEventIcon(VehicleEventType type) {
    switch (type) {
      case VehicleEventType.harshBraking:
        return Icons.warning;
      case VehicleEventType.harshAcceleration:
        return Icons.speed;
      case VehicleEventType.speeding:
        return Icons.speed;
      default:
        return Icons.info;
    }
  }

  String _getEventName(VehicleEventType type) {
    switch (type) {
      case VehicleEventType.harshBraking:
        return 'Harsh Braking';
      case VehicleEventType.harshAcceleration:
        return 'Harsh Acceleration';
      case VehicleEventType.speeding:
        return 'Speeding';
      case VehicleEventType.harshCornering:
        return 'Harsh Cornering';
      case VehicleEventType.idling:
        return 'Excessive Idling';
      case VehicleEventType.rolling:
        return 'Rolling';
      case VehicleEventType.engineFault:
        return 'Engine Fault';
    }
  }
}
