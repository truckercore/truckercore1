class HOSSummary {
  final String id;
  final String driverId;
  final DateTime date;
  final double driveTime; // hours
  final double onDutyTime;
  final double offDutyTime;
  final double cycleTime;
  final double maxDriveTime;
  final double maxShiftTime;
  final double maxCycleTime;

  HOSSummary({
    required this.id,
    required this.driverId,
    required this.date,
    required this.driveTime,
    required this.onDutyTime,
    required this.offDutyTime,
    required this.cycleTime,
    this.maxDriveTime = 11.0,
    this.maxShiftTime = 14.0,
    this.maxCycleTime = 70.0,
  });

  factory HOSSummary.fromJson(Map<String, dynamic> json) {
    return HOSSummary(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      date: DateTime.parse(json['date'] as String),
      driveTime: (json['drive_time'] as num).toDouble(),
      onDutyTime: (json['on_duty_time'] as num).toDouble(),
      offDutyTime: (json['off_duty_time'] as num).toDouble(),
      cycleTime: (json['cycle_time'] as num).toDouble(),
      maxDriveTime: (json['max_drive_time'] as num?)?.toDouble() ?? 11.0,
      maxShiftTime: (json['max_shift_time'] as num?)?.toDouble() ?? 14.0,
      maxCycleTime: (json['max_cycle_time'] as num?)?.toDouble() ?? 70.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'date': date.toIso8601String(),
      'drive_time': driveTime,
      'on_duty_time': onDutyTime,
      'off_duty_time': offDutyTime,
      'cycle_time': cycleTime,
      'max_drive_time': maxDriveTime,
      'max_shift_time': maxShiftTime,
      'max_cycle_time': maxCycleTime,
    };
  }

  double get driveTimeRemaining => (maxDriveTime - driveTime).clamp(0, maxDriveTime);
  double get shiftTimeRemaining => (maxShiftTime - onDutyTime).clamp(0, maxShiftTime);
  double get cycleTimeRemaining => (maxCycleTime - cycleTime).clamp(0, maxCycleTime);
}
