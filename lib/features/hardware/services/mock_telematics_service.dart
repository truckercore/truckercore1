import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/telematics_data.dart';

/// Mock telematics service that simulates hardware device data
/// In production, this would integrate with actual telematics hardware APIs
final mockTelematicsServiceProvider = Provider<MockTelematicsService>((ref) {
  return MockTelematicsService();
});

class MockTelematicsService {
  final Random _random = Random();
  final List<StreamController<TelematicsData>> _controllers = [];

  /// Start simulating telematics data for a vehicle
  Stream<TelematicsData> streamVehicleData(String vehicleId) {
    final controller = StreamController<TelematicsData>.broadcast();
    _controllers.add(controller);

    // Simulate data updates every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      final data = _generateMockData(vehicleId);
      controller.add(data);
    });

    return controller.stream;
  }

  /// Generate mock telematics data
  TelematicsData _generateMockData(String vehicleId) {
    // Simulate realistic truck driving data
    final baseSpeed = 55.0 + _random.nextDouble() * 15; // 55-70 mph
    final rpm = 1200 + _random.nextInt(600); // 1200-1800 RPM
    final fuelLevel = 45.0 + _random.nextDouble() * 50; // 45-95%

    // Simulate occasional events
    final hasHarshBraking = _random.nextDouble() < 0.05; // 5% chance
    final hasHarshAcceleration = _random.nextDouble() < 0.05;
    final isSpeeding = baseSpeed > 65;

    return TelematicsData(
      vehicleId: vehicleId,
      timestamp: DateTime.now(),
      latitude: 40.7128 + (_random.nextDouble() - 0.5) * 0.1,
      longitude: -74.0060 + (_random.nextDouble() - 0.5) * 0.1,
      speed: baseSpeed,
      heading: _random.nextInt(360).toDouble(),
      odometer: 150000 + _random.nextInt(1000),
      engineRpm: rpm,
      fuelLevel: fuelLevel,
      engineTemperature: 195 + _random.nextInt(15), // 195-210°F
      coolantTemperature: 190 + _random.nextInt(10),
      oilPressure: 35 + _random.nextInt(20), // 35-55 PSI
      batteryVoltage: 12.5 + _random.nextDouble() * 1.5,
      tirePressures: TirePressures(
        frontLeft: 100 + _random.nextInt(10),
        frontRight: 100 + _random.nextInt(10),
        rearLeft: 100 + _random.nextInt(10),
        rearRight: 100 + _random.nextInt(10),
      ),
      events: _generateEvents(hasHarshBraking, hasHarshAcceleration, isSpeeding),
      diagnosticCodes: _random.nextDouble() < 0.01 ? ['P0420'] : [], // 1% chance of DTC
    );
  }

  List<VehicleEvent> _generateEvents(
    bool hasHarshBraking,
    bool hasHarshAcceleration,
    bool isSpeeding,
  ) {
    final events = <VehicleEvent>[];

    if (hasHarshBraking) {
      events.add(VehicleEvent(
        type: VehicleEventType.harshBraking,
        severity: 0.7 + _random.nextDouble() * 0.3,
        timestamp: DateTime.now(),
      ));
    }

    if (hasHarshAcceleration) {
      events.add(VehicleEvent(
        type: VehicleEventType.harshAcceleration,
        severity: 0.6 + _random.nextDouble() * 0.3,
        timestamp: DateTime.now(),
      ));
    }

    if (isSpeeding) {
      events.add(VehicleEvent(
        type: VehicleEventType.speeding,
        severity: 0.5 + _random.nextDouble() * 0.2,
        timestamp: DateTime.now(),
      ));
    }

    return events;
  }

  /// Simulate ELD (Electronic Logging Device) connection status
  Stream<ELDConnectionStatus> streamELDStatus(String vehicleId) {
    return Stream.periodic(const Duration(seconds: 10), (_) {
      return ELDConnectionStatus(
        vehicleId: vehicleId,
        connected: _random.nextDouble() > 0.05, // 95% uptime
        signalStrength: 60 + _random.nextInt(40), // 60-100%
        lastHeartbeat: DateTime.now(),
        firmwareVersion: '2.4.1',
        deviceId: 'ELD-${vehicleId.substring(0, vehicleId.length > 8 ? 8 : vehicleId.length)}',
      );
    });
  }

  /// Simulate GPS tracker data
  Stream<GPSTrackerData> streamGPSData(String vehicleId) {
    return Stream.periodic(const Duration(seconds: 3), (_) {
      return GPSTrackerData(
        vehicleId: vehicleId,
        latitude: 40.7128 + (_random.nextDouble() - 0.5) * 0.1,
        longitude: -74.0060 + (_random.nextDouble() - 0.5) * 0.1,
        altitude: 50 + _random.nextInt(100).toDouble(),
        speed: 55.0 + _random.nextDouble() * 15,
        heading: _random.nextInt(360).toDouble(),
        accuracy: 5 + _random.nextInt(15).toDouble(), // 5-20 meters
        satellites: 8 + _random.nextInt(5), // 8-12 satellites
        timestamp: DateTime.now(),
      );
    });
  }

  /// Simulate dashcam/camera feed status
  Stream<DashcamStatus> streamDashcamStatus(String vehicleId) {
    return Stream.periodic(const Duration(seconds: 15), (_) {
      return DashcamStatus(
        vehicleId: vehicleId,
        recording: true,
        storageUsed: 45 + _random.nextInt(40), // 45-85%
        lastEventRecorded: _random.nextDouble() < 0.3
            ? DateTime.now().subtract(Duration(minutes: _random.nextInt(60)))
            : null,
        cameraHealthy: _random.nextDouble() > 0.05, // 95% healthy
      );
    });
  }

  /// Simulate tire pressure monitoring system (TPMS)
  Stream<TPMSData> streamTPMSData(String vehicleId) {
    return Stream.periodic(const Duration(seconds: 30), (_) {
      return TPMSData(
        vehicleId: vehicleId,
        frontLeftPressure: 100 + _random.nextInt(10),
        frontRightPressure: 100 + _random.nextInt(10),
        rearLeftPressure: 100 + _random.nextInt(10),
        rearRightPressure: 100 + _random.nextInt(10),
        frontLeftTemp: 70 + _random.nextInt(30), // 70-100°F
        frontRightTemp: 70 + _random.nextInt(30),
        rearLeftTemp: 70 + _random.nextInt(30),
        rearRightTemp: 70 + _random.nextInt(30),
        alerts: _generateTPMSAlerts(),
        timestamp: DateTime.now(),
      );
    });
  }

  List<TPMSAlert> _generateTPMSAlerts() {
    final alerts = <TPMSAlert>[];

    // Simulate low pressure alert occasionally
    if (_random.nextDouble() < 0.1) {
      alerts.add(TPMSAlert(
        type: TPMSAlertType.lowPressure,
        tire: ['frontLeft', 'frontRight', 'rearLeft', 'rearRight'][_random.nextInt(4)],
        message: 'Tire pressure below recommended level',
      ));
    }

    // Simulate high temperature alert occasionally
    if (_random.nextDouble() < 0.05) {
      alerts.add(TPMSAlert(
        type: TPMSAlertType.highTemperature,
        tire: ['frontLeft', 'frontRight', 'rearLeft', 'rearRight'][_random.nextInt(4)],
        message: 'Tire temperature above normal range',
      ));
    }

    return alerts;
  }

  /// Simulate OBDII diagnostic data
  Stream<OBDIIData> streamOBDIIData(String vehicleId) {
    return Stream.periodic(const Duration(seconds: 10), (_) {
      return OBDIIData(
        vehicleId: vehicleId,
        engineLoad: 25 + _random.nextInt(50), // 25-75%
        coolantTemp: 190 + _random.nextInt(15), // 190-205°F
        fuelPressure: 45 + _random.nextInt(20), // 45-65 PSI
        intakeManifoldPressure: 10 + _random.nextInt(15), // 10-25 inHg
        engineRPM: 1200 + _random.nextInt(600),
        vehicleSpeed: 55 + _random.nextInt(15),
        timingAdvance: 10 + _random.nextInt(10).toDouble(),
        intakeAirTemp: 80 + _random.nextInt(30),
        mafAirFlowRate: 15 + _random.nextInt(20).toDouble(),
        throttlePosition: 20 + _random.nextInt(40),
        oxygenSensor1Voltage: 0.1 + _random.nextDouble() * 0.8,
        fuelLevel: 45 + _random.nextInt(50),
        troubleCodes: _random.nextDouble() < 0.02 ? ['P0420', 'P0300'] : [],
        timestamp: DateTime.now(),
      );
    });
  }

  /// Simulate trailer connection status
  Stream<TrailerStatus> streamTrailerStatus(String vehicleId) {
    return Stream.periodic(const Duration(seconds: 20), (_) {
      final isConnected = _random.nextDouble() > 0.1; // 90% connected

      return TrailerStatus(
        vehicleId: vehicleId,
        connected: isConnected,
        trailerId: isConnected ? 'TRAILER-${_random.nextInt(1000)}' : null,
        lightsWorking: isConnected ? _random.nextDouble() > 0.05 : false,
        brakesConnected: isConnected ? _random.nextDouble() > 0.03 : false,
        absOperational: isConnected ? _random.nextDouble() > 0.05 : false,
        weight: isConnected ? 30000 + _random.nextInt(50000) : null,
        timestamp: DateTime.now(),
      );
    });
  }

  /// Clean up resources
  void dispose() {
    for (final controller in _controllers) {
      controller.close();
    }
    _controllers.clear();
  }
}
