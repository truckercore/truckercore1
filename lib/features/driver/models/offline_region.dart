class OfflineRegion {
  final String id;
  final String name;
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;
  final int minZoom;
  final int maxZoom;
  final bool downloaded;
  final DateTime? downloadedAt;

  const OfflineRegion({
    required this.id,
    required this.name,
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
    required this.minZoom,
    required this.maxZoom,
    this.downloaded = false,
    this.downloadedAt,
  });

  factory OfflineRegion.fromJson(Map<String, dynamic> json) => OfflineRegion(
        id: json['id'] as String,
        name: json['name'] as String,
        minLat: (json['min_lat'] as num).toDouble(),
        minLng: (json['min_lng'] as num).toDouble(),
        maxLat: (json['max_lat'] as num).toDouble(),
        maxLng: (json['max_lng'] as num).toDouble(),
        minZoom: json['min_zoom'] as int,
        maxZoom: json['max_zoom'] as int,
        downloaded: json['downloaded'] as bool? ?? false,
        downloadedAt: json['downloaded_at'] != null
            ? DateTime.parse(json['downloaded_at'] as String)
            : null,
      );
}
