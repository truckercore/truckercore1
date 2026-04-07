class DriverStatus {
  final String id;
  final String driverId;
  final String status; // on_duty, off_duty, driving, sleeper
  final DateTime? statusChangedAt;
  final double? driveTimeLeft; // in hours
  final double? shiftTimeLeft;
  final double? cycleTimeLeft;

  DriverStatus({
    required this.id,
    required this.driverId,
    required this.status,
    this.statusChangedAt,
    this.driveTimeLeft,
    this.shiftTimeLeft,
    this.cycleTimeLeft,
  });

  factory DriverStatus.fromJson(Map<String, dynamic> json) {
    return DriverStatus(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      status: json['status'] as String,
      statusChangedAt: json['status_changed_at'] != null
          ? DateTime.parse(json['status_changed_at'] as String)
          : null,
      driveTimeLeft: (json['drive_time_left'] as num?)?.toDouble(),
      shiftTimeLeft: (json['shift_time_left'] as num?)?.toDouble(),
      cycleTimeLeft: (json['cycle_time_left'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'status': status,
      'status_changed_at': statusChangedAt?.toIso8601String(),
      'drive_time_left': driveTimeLeft,
      'shift_time_left': shiftTimeLeft,
      'cycle_time_left': cycleTimeLeft,
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'on_duty':
        return 'On Duty';
      case 'off_duty':
        return 'Off Duty';
      case 'driving':
        return 'Driving';
      case 'sleeper':
        return 'Sleeper Berth';
      default:
        return status;
    }
  }

  bool get isActive => status == 'on_duty' || status == 'driving';
}
