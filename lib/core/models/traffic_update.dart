class TrafficUpdate {
  final String id;
  final String routeId;
  final String type; // e.g., congestion, accident
  final String description;
  final int? delayMinutes;
  final DateTime createdAt;

  TrafficUpdate({
    required this.id,
    required this.routeId,
    required this.type,
    required this.description,
    this.delayMinutes,
    required this.createdAt,
  });

  factory TrafficUpdate.fromJson(Map<String, dynamic> json) => TrafficUpdate(
        id: json['id']?.toString() ?? '',
        routeId: json['route_id']?.toString() ?? '',
        type: json['type'] as String? ?? 'unknown',
        description: json['description'] as String? ?? '',
        delayMinutes: (json['delay_minutes'] as num?)?.toInt(),
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}
