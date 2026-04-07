# Flutter Map Clustering (Driver Map)

This module adds a minimal, implementation-ready clustered map for the driver experience using flutter_map + flutter_map_marker_cluster.

Key pieces
- Model: lib/map/stop_pin.dart
- Scoring: lib/map/scoring.dart
- Data merge service: lib/map/data/poi_promos_repository.dart
- Widget: lib/map/widgets/cluster_map.dart
- Demo page: lib/map/pages/map_cluster_demo.dart

Dependencies
- flutter_map (already in pubspec)
- flutter_map_marker_cluster (already in pubspec)

Data sources
- GET {SUPABASE_URL}/functions/v1/state.parking?bbox=west,south,east,north&min_conf=0.0
- GET {SUPABASE_URL}/functions/v1/promotions.nearby?lat=..&lng=..&radius_mi=..

How it works
1. ClusterMap builds a flutter_map and listens to pan/zoom events.
2. On move end, it fetches parking state for current bbox and nearby promotions for the map center.
3. PoiPromosRepository merges the two into StopPin objects, attaching best fuel discount and a naive loyalty value.
4. Pins are clustered. On cluster tap, a bottom sheet shows the representative stop (“Best in this cluster”) with why-factors and the rest sorted by score.
5. A global banner shows the top-scoring stop across all visible pins (“Best for you”).

Usage
```
Navigator.push(context, MaterialPageRoute(
  builder: (_) => MapClusterDemoPage(
    lat: 35.4676, // Oklahoma City
    lng: -97.5164,
    getAuthToken: () async => 'Bearer ${await yourSessionToken()}'
  )
));
```

Notes
- Repository has a 10s in-memory cache by bbox and a 300–350ms debounce on map movement.
- Scoring weights: parking 0.35, fuel 0.25, loyalty 0.15, amenities 0.15, distance 0.10, confidence 0.10.
- Occupancy colors: green=open, orange=some, red=full; confidence drives outline opacity.
- For production, replace the naive loyalty heuristic with real user preferences and amenity matches.
