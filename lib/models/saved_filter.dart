class SavedFilter {
  final String id;
  final String userId;
  final String scope;
  final String name;
  final Map<String, dynamic> json;
  final DateTime? createdAt;
  const SavedFilter({
    required this.id,
    required this.userId,
    required this.scope,
    required this.name,
    required this.json,
    this.createdAt,
  });
  factory SavedFilter.fromJson(Map<String, dynamic> j) => SavedFilter(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    scope: j['scope'] as String,
    name: j['name'] as String,
    json: Map<String, dynamic>.from(j['json'] as Map? ?? const {}),
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'].toString())
        : null,
  );
}
