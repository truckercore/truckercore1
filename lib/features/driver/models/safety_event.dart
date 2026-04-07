enum SafetyEventType {
  harshBraking,
  harshAcceleration,
  harshCornering,
  speeding,
  rolling,
  idling,
  seatbeltViolation,
  distraction,
}

class SafetyEvent {
  final String id;
  final SafetyEventType type;
  final double severity;
  final double lat;
  final double lng;
  final double speed;
  final DateTime timestamp;
  final Map<String, dynamic>? telemetry;
  final bool coached;

  const SafetyEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.timestamp,
    this.telemetry,
    this.coached = false,
  });

  factory SafetyEvent.fromJson(Map<String, dynamic> json) => SafetyEvent(
        id: json['id'] as String,
        type: SafetyEventType.values.firstWhere(
          (e) => e.name == json['event_type'],
        ),
        severity: (json['severity'] as num).toDouble(),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        speed: (json['speed'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        telemetry: json['telemetry'] as Map<String, dynamic>?,
        coached: json['coached'] as bool? ?? false,
      );
}

class DrivingSafetyScore {
  final String driverId;
  final double overallScore;
  final double speedingScore;
  final double brakingScore;
  final double accelerationScore;
  final double corneringScore;
  final int totalEvents;
  final DateTime updatedAt;

  const DrivingSafetyScore({
    required this.driverId,
    required this.overallScore,
    required this.speedingScore,
    required this.brakingScore,
    required this.accelerationScore,
    required this.corneringScore,
    required this.totalEvents,
    required this.updatedAt,
  });

  factory DrivingSafetyScore.fromJson(Map<String, dynamic> json) => DrivingSafetyScore(
        driverId: json['driver_id'] as String,
        overallScore: (json['overall_score'] as num).toDouble(),
        speedingScore: (json['speeding_score'] as num).toDouble(),
        brakingScore: (json['braking_score'] as num).toDouble(),
        accelerationScore: (json['acceleration_score'] as num).toDouble(),
        corneringScore: (json['cornering_score'] as num).toDouble(),
        totalEvents: json['total_events'] as int,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class DrivingBehaviorAnalytics {
  final int totalTrips;
  final double totalMiles;
  final int safetyEventsCount;
  final double eventsPerMile;
  final Map<SafetyEventType, int> eventsByType;
  final List<TimeOfDayPattern> riskPatterns;

  const DrivingBehaviorAnalytics({
    required this.totalTrips,
    required this.totalMiles,
    required this.safetyEventsCount,
    required this.eventsPerMile,
    required this.eventsByType,
    required this.riskPatterns,
  });

  factory DrivingBehaviorAnalytics.fromJson(Map<String, dynamic> json) {
    final eventsByType = <SafetyEventType, int>{};
    final eventsMap = json['events_by_type'] as Map<String, dynamic>;
    eventsMap.forEach((key, value) {
      final type = SafetyEventType.values.firstWhere((e) => e.name == key);
      eventsByType[type] = value as int;
    });

    return DrivingBehaviorAnalytics(
      totalTrips: json['total_trips'] as int,
      totalMiles: (json['total_miles'] as num).toDouble(),
      safetyEventsCount: json['safety_events_count'] as int,
      eventsPerMile: (json['events_per_mile'] as num).toDouble(),
      eventsByType: eventsByType,
      riskPatterns: (json['risk_patterns'] as List)
          .map((p) => TimeOfDayPattern.fromJson(p))
          .toList(),
    );
  }
}

class TimeOfDayPattern {
  final String timeRange;
  final int eventCount;
  final double riskLevel;

  const TimeOfDayPattern({
    required this.timeRange,
    required this.eventCount,
    required this.riskLevel,
  });

  factory TimeOfDayPattern.fromJson(Map<String, dynamic> json) => TimeOfDayPattern(
        timeRange: json['time_range'] as String,
        eventCount: json['event_count'] as int,
        riskLevel: (json['risk_level'] as num).toDouble(),
      );
}

class SpeedViolation {
  final String id;
  final double speedLimit;
  final double actualSpeed;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final bool acknowledged;

  const SpeedViolation({
    required this.id,
    required this.speedLimit,
    required this.actualSpeed,
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.acknowledged = false,
  });

  factory SpeedViolation.fromJson(Map<String, dynamic> json) => SpeedViolation(
        id: json['id'] as String,
        speedLimit: (json['speed_limit'] as num).toDouble(),
        actualSpeed: (json['actual_speed'] as num).toDouble(),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        acknowledged: json['acknowledged'] as bool? ?? false,
      );
}

class SafetyTip {
  final String title;
  final String description;
  final String category;

  const SafetyTip({
    required this.title,
    required this.description,
    required this.category,
  });

  factory SafetyTip.fromJson(Map<String, dynamic> json) => SafetyTip(
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String,
      );
}
