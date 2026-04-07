/// Minimal Org model stub to align with TruckerCore shared package sketch.
/// Manual (no codegen) JSON helpers to avoid build_runner dependency.
class Org {
  final String id;
  final String name;
  final String? tier; // free|pro|enterprise
  final Map<String, dynamic>? metadata;

  const Org({
    required this.id,
    required this.name,
    this.tier,
    this.metadata,
  });

  factory Org.fromJson(Map<String, dynamic> json) {
    return Org(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      tier: json['tier']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? (json['metadata'] as Map<String, dynamic>)
          : (json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : null),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (tier != null) 'tier': tier,
        if (metadata != null) 'metadata': metadata,
      };
}
