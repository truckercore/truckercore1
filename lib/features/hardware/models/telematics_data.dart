class TelematicsData {
  final String vehicleId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final int odometer;
  final int engineRpm;
  final double fuelLevel;
  final int engineTemperature;
  final int coolantTemperature;
  final int oilPressure;
  final double batteryVoltage;
  final TirePressures tirePressures;
  final List<VehicleEvent> events;
  final List<String> diagnosticCodes;

  const TelematicsData({
    required this.vehicleId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.odometer,
    required this.engineRpm,
    required this.fuelLevel,
    required this.engineTemperature,
    required this.coolantTemperature,
    required this.oilPressure,
    required this.batteryVoltage,
    required this.tirePressures,
    required this.events,
    required this.diagnosticCodes,
  });
}

class TirePressures {
  final int frontLeft;
  final int frontRight;
  final int rearLeft;
  final int rearRight;

  const TirePressures({
    required this.frontLeft,
    required this.frontRight,
    required this.rearLeft,
    required this.rearRight,
  });
}

enum VehicleEventType {
  harshBraking,
  harshAcceleration,
  harshCornering,
  speeding,
  idling,
  rolling,
  engineFault,
}

class VehicleEvent {
  final VehicleEventType type;
  final double severity;
  final DateTime timestamp;

  const VehicleEvent({
    required this.type,
    required this.severity,
    required this.timestamp,
  });
}

class ELDConnectionStatus {
  final String vehicleId;
  final bool connected;
  final int signalStrength;
  final DateTime lastHeartbeat;
  final String firmwareVersion;
  final String deviceId;

  const ELDConnectionStatus({
    required this.vehicleId,
    required this.connected,
    required this.signalStrength,
    required this.lastHeartbeat,
    required this.firmwareVersion,
    required this.deviceId,
  });
}

class GPSTrackerData {
  final String vehicleId;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double heading;
  final double accuracy;
  final int satellites;
  final DateTime timestamp;

  const GPSTrackerData({
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.heading,
    required this.accuracy,
    required this.satellites,
    required this.timestamp,
  });
}

class DashcamStatus {
  final String vehicleId;
  final bool recording;
  final int storageUsed;
  final DateTime? lastEventRecorded;
  final bool cameraHealthy;

  const DashcamStatus({
    required this.vehicleId,
    required this.recording,
    required this.storageUsed,
    this.lastEventRecorded,
    required this.cameraHealthy,
  });
}

class TPMSData {
  final String vehicleId;
  final int frontLeftPressure;
  final int frontRightPressure;
  final int rearLeftPressure;
  final int rearRightPressure;
  final int frontLeftTemp;
  final int frontRightTemp;
  final int rearLeftTemp;
  final int rearRightTemp;
  final List<TPMSAlert> alerts;
  final DateTime timestamp;

  const TPMSData({
    required this.vehicleId,
    required this.frontLeftPressure,
    required this.frontRightPressure,
    required this.rearLeftPressure,
    required this.rearRightPressure,
    required this.frontLeftTemp,
    required this.frontRightTemp,
    required this.rearLeftTemp,
    required this.rearRightTemp,
    required this.alerts,
    required this.timestamp,
  });
}

enum TPMSAlertType {
  lowPressure,
  highPressure,
  highTemperature,
  sensorFault,
}

class TPMSAlert {
  final TPMSAlertType type;
  final String tire;
  final String message;

  const TPMSAlert({
    required this.type,
    required this.tire,
    required this.message,
  });
}

class OBDIIData {
  final String vehicleId;
  final int engineLoad;
  final int coolantTemp;
  final int fuelPressure;
  final int intakeManifoldPressure;
  final int engineRPM;
  final int vehicleSpeed;
  final double timingAdvance;
  final int intakeAirTemp;
  final double mafAirFlowRate;
  final int throttlePosition;
  final double oxygenSensor1Voltage;
  final int fuelLevel;
  final List<String> troubleCodes;
  final DateTime timestamp;

  const OBDIIData({
    required this.vehicleId,
    required this.engineLoad,
    required this.coolantTemp,
    required this.fuelPressure,
    required this.intakeManifoldPressure,
    required this.engineRPM,
    required this.vehicleSpeed,
    required this.timingAdvance,
    required this.intakeAirTemp,
    required this.mafAirFlowRate,
    required this.throttlePosition,
    required this.oxygenSensor1Voltage,
    required this.fuelLevel,
    required this.troubleCodes,
    required this.timestamp,
  });
}

class TrailerStatus {
  final String vehicleId;
  final bool connected;
  final String? trailerId;
  final bool lightsWorking;
  final bool brakesConnected;
  final bool absOperational;
  final int? weight;
  final DateTime timestamp;

  const TrailerStatus({
    required this.vehicleId,
    required this.connected,
    this.trailerId,
    required this.lightsWorking,
    required this.brakesConnected,
    required this.absOperational,
    this.weight,
    required this.timestamp,
  });
}
