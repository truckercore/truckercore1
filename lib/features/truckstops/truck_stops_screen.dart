import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/config/app_config.dart';
import '../../common/utils/geo.dart';
import '../../common/widgets/featured_badge.dart';

class TruckStopsScreen extends ConsumerStatefulWidget {
  const TruckStopsScreen({super.key});

  @override
  ConsumerState<TruckStopsScreen> createState() => _TruckStopsScreenState();
}

class _TruckStopsScreenState extends ConsumerState<TruckStopsScreen> {
  // Filters
  bool filterParkingNow = false;
  bool filterShowers = false;
  bool filterFood = false;
  bool filterDiesel = false;
  bool filterAlongRoute = false; // stub corridor
  double filterRadiusMi = 25;
  bool insertAsDetour = true;
  late Future<List<TruckStop>> _stopsFut;
  late Future<List<TruckStopDeal>> _dealsFut;

  final Map<String, StreamSubscription> _parkingSubs = {};
  final Map<String, TruckStopParking?> _latestParking = {};

  LatLng? _myPos;

  @override
  void initState() {
    super.initState();
    final svc = ref.read(truckStopServiceProvider);
    _stopsFut = _fetchStopsWithCache(svc);
    _dealsFut = _fetchDealsWithCache(svc);
    // Try to get user location (best-effort)
    safeCurrentPosition().then((p) {
      if (mounted) setState(() => _myPos = p);
    });
  }

  @override
  void dispose() {
    for (final sub in _parkingSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<List<TruckStop>> _loadCachedStops() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('truckstops_cache_stops');
    if (s == null) return const <TruckStop>[];
    try {
      final list = (jsonDecode(s) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(TruckStop.fromMap)
          .toList();
      return list;
    } catch (_) {
      return const <TruckStop>[];
    }
  }

  Future<List<TruckStopDeal>> _loadCachedDeals() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('truckstops_cache_deals');
    if (s == null) return const <TruckStopDeal>[];
    try {
      final list = (jsonDecode(s) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((m) => TruckStopDeal(truckStopId: m['truck_stop_id'] as String, title: m['title'] as String))
          .toList();
      return list;
    } catch (_) {
      return const <TruckStopDeal>[];
    }
  }

  Future<void> _persistCache(List<TruckStop> stops, List<TruckStopDeal> deals) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final stopsMin = stops
          .map((e) => {
                'id': e.id,
                'name': e.name,
                'address': e.address,
                'lat': e.lat,
                'lng': e.lng,
                'tier': e.tier,
              })
          .toList();
      final dealsMin = deals
          .map((d) => {
                'truck_stop_id': d.truckStopId,
                'title': d.title,
              })
          .toList();
      await prefs.setString('truckstops_cache_stops', jsonEncode(stopsMin));
      await prefs.setString('truckstops_cache_deals', jsonEncode(dealsMin));
      await prefs.setInt('truckstops_cache_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<List<TruckStop>> _fetchStopsWithCache(TruckStopService svc) async {
    try {
      final stops = await svc.fetchTruckStops();
      // Persist asynchronously with deals when both finish; but we save partial too
      final deals = await _loadCachedDeals();
      // save stops + existing cached deals
      // ignore failures
      unawaited(_persistCache(stops, deals));
      return stops;
    } catch (_) {
      // Offline path
      return _loadCachedStops();
    }
  }

  Future<List<TruckStopDeal>> _fetchDealsWithCache(TruckStopService svc) async {
    try {
      final deals = await svc.fetchActiveDeals();
      final stops = await _loadCachedStops();
      unawaited(_persistCache(stops, deals));
      return deals;
    } catch (_) {
      return _loadCachedDeals();
    }
  }

  Future<void> _navigateToStop(BuildContext ctx, TruckStop s) async {
    try {
      await Supabase.instance.client.from('dispatch_events').insert({
        'event_type': 'nav_waypoint_set',
        'details': {
          'stop_id': s.id,
          'name': s.name,
          'lat': s.lat,
          'lng': s.lng,
          'mode': insertAsDetour ? 'detour' : 'replace',
        },
      });
    } catch (_) {}
    if (!ctx.mounted) {
      return;
    }
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Inserted as next waypoint (mock).')),
    );
  }

  void _callStop(BuildContext ctx) {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(const SnackBar(content: Text('Call stop (not available)')));
  }

  void _viewDetails(BuildContext ctx, TruckStop s) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(s.name),
        content: Text(
          'Lat: ${s.lat}, Lng: ${s.lng}\nAddress: ${s.address ?? '-'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _subscribeParking(String stopId) {
    if (_parkingSubs.containsKey(stopId)) return;
    final svc = ref.read(truckStopServiceProvider);
    // Subscribe to realtime changes
    final sub = svc.parkingStream(stopId).listen((p) {
      setState(() {
        _latestParking[stopId] = p;
      });
    });
    _parkingSubs[stopId] = sub;
  }

  double _minMilesToPolyline(List<LatLng> path, LatLng p) {
    if (path.length == 1) return milesBetween(path.first, p);
    double best = double.infinity;
    for (var i = 0; i < path.length; i++) {
      best = best < milesBetween(path[i], p) ? best : milesBetween(path[i], p);
      if (i + 1 < path.length) {
        // Check midpoint heuristic for each segment
        final a = path[i];
        final b = path[i + 1];
        final mid = LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
        final dMid = milesBetween(mid, p);
        if (dMid < best) best = dMid;
      }
    }
    return best.isFinite ? best : 1e9;
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(truckStopServiceProvider);
    // Route polyline filter integration is optional; default to none when not available
    final List<LatLng> routePolyline = const <LatLng>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Truck Stops')),
      body: FutureBuilder(
        future: Future.wait([_stopsFut, _dealsFut]),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data as List<dynamic>;
          var stops = (data[0] as List<TruckStop>).toList();
          final deals = data[1] as List<TruckStopDeal>;

          // Optional: sort by tier (featured first) then by distance if available
          stops.sort((a, b) {
            int tierScore(String t) => t == 'enterprise'
                ? 2
                : t == 'pro'
                ? 1
                : 0;
            final tierCmp = tierScore(b.tier).compareTo(tierScore(a.tier));
            if (tierCmp != 0) return tierCmp;
            if (_myPos == null) return a.name.compareTo(b.name);
            final da = milesBetween(_myPos!, LatLng(a.lat, a.lng));
            final db = milesBetween(_myPos!, LatLng(b.lat, b.lng));
            return da.compareTo(db);
          });

          // Group deals by truck stop
          final dealsByStop = <String, List<TruckStopDeal>>{};
          for (final d in deals) {
            dealsByStop.putIfAbsent(d.truckStopId, () => []).add(d);
          }

          // Filters row
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('Parking now'),
                      selected: filterParkingNow,
                      onSelected: (v) => setState(() => filterParkingNow = v),
                    ),
                    FilterChip(
                      label: const Text('Showers'),
                      selected: filterShowers,
                      onSelected: (v) => setState(() => filterShowers = v),
                    ),
                    FilterChip(
                      label: const Text('Food'),
                      selected: filterFood,
                      onSelected: (v) => setState(() => filterFood = v),
                    ),
                    FilterChip(
                      label: const Text('Diesel/DEF'),
                      selected: filterDiesel,
                      onSelected: (v) => setState(() => filterDiesel = v),
                    ),
                    FilterChip(
                      label: const Text('Along my route'),
                      selected: filterAlongRoute,
                      onSelected: (v) => setState(() => filterAlongRoute = v),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Insert as detour'),
                        Switch(
                          value: insertAsDetour,
                          onChanged: (v) => setState(() => insertAsDetour = v),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Within'),
                        const SizedBox(width: 6),
                        DropdownButton<double>(
                          value: filterRadiusMi,
                          items: const [10, 25, 50, 100]
                              .map(
                                (e) => DropdownMenuItem<double>(
                                  value: e.toDouble(),
                                  child: Text('$e mi'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => filterRadiusMi = v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    // Apply filters to list
                    List<TruckStop> list = stops;
                    if (_myPos != null) {
                      list = list.where((s) {
                        final d = milesBetween(_myPos!, LatLng(s.lat, s.lng));
                        return d <= filterRadiusMi;
                      }).toList();
                    }
                    // parking now filter by latestParking >0
                    if (filterParkingNow) {
                      list = list.where((s) {
                        final p = _latestParking[s.id];
                        return p != null && p.availableSpots > 0;
                      }).toList();
                    }
                    // Along-route corridor filter using route polyline and 5-mi buffer
                    if (filterAlongRoute && routePolyline.length >= 2) {
                      const bufferMi = 5.0;
                      list = list.where((s) {
                        final d = _minMilesToPolyline(routePolyline, LatLng(s.lat, s.lng));
                        return d <= bufferMi;
                      }).toList();
                    }
                    // For showers/food/diesel: placeholder using deals keywords until amenities are modeled
                    if (filterShowers) {
                      list = list.where((s) {
                        final ds = dealsByStop[s.id] ?? const <TruckStopDeal>[];
                        return ds.any(
                          (d) => d.title.toLowerCase().contains('shower'),
                        );
                      }).toList();
                    }
                    if (filterFood) {
                      list = list.where((s) {
                        final ds = dealsByStop[s.id] ?? const <TruckStopDeal>[];
                        return ds.any(
                          (d) =>
                              d.title.toLowerCase().contains('food') ||
                              d.title.toLowerCase().contains('restaurant'),
                        );
                      }).toList();
                    }
                    if (filterDiesel) {
                      list = list.where((s) {
                        final ds = dealsByStop[s.id] ?? const <TruckStopDeal>[];
                        return ds.any(
                          (d) =>
                              d.title.toLowerCase().contains('diesel') ||
                              d.title.toLowerCase().contains('def'),
                        );
                      }).toList();
                    }
                    stops = list;

                    if (stops.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('No results'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => setState(
                                    () => filterRadiusMi = (filterRadiusMi * 2)
                                        .clamp(10, 200),
                                  ),
                                  child: const Text('Widen radius'),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      setState(() => filterParkingNow = false),
                                  child: const Text('Remove filters'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: stops.length,
                      itemBuilder: (context, i) {
                        final s = stops[i];
                        _subscribeParking(s.id);
                        final p = _latestParking[s.id];
                        final stopDeals =
                            dealsByStop[s.id] ?? const <TruckStopDeal>[];

                        final featured = s.tier != 'free';
                        final distText = _myPos == null
                            ? null
                            : '${milesBetween(_myPos!, LatLng(s.lat, s.lng)).toStringAsFixed(1)} mi';

                        return Card(
                          key: ValueKey(s.id),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Map placeholder
                                Container(
                                  height: 160,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: Text('Map (markers filtered)'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (distText != null) Text(distText),
                                    const SizedBox(width: 8),
                                    FeaturedBadge(featured: featured),
                                    if (featured) const SizedBox(width: 6),
                                    if (featured)
                                      const Text(
                                        'Sponsored',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                if (s.address != null) Text(s.address!),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.local_parking, size: 18),
                                    const SizedBox(width: 6),
                                    if (p == null)
                                      FutureBuilder(
                                        future: svc.latestParkingFor(s.id),
                                        builder: (context, snapP) {
                                          if (snapP.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Text(
                                              'Loading parking...',
                                            );
                                          }
                                          if (!snapP.hasData ||
                                              snapP.data == null) {
                                            return const Text(
                                              'No parking data',
                                            );
                                          }
                                          final pp =
                                              snapP.data as TruckStopParking;
                                          return Text(
                                            '${pp.availableSpots}/${pp.totalSpots} available',
                                          );
                                        },
                                      )
                                    else
                                      Row(
                                        children: [
                                          _occupancyBadge(p),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${p.availableSpots}/${p.totalSpots} available',
                                          ),
                                          if (p.updatedAt != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Text(
                                                'as of ${_age(p.updatedAt!)}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _navigateToStop(context, s),
                                      icon: const Icon(Icons.navigation),
                                      label: const Text('Navigate'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _callStop(context),
                                      icon: const Icon(Icons.call),
                                      label: const Text('Call'),
                                    ),
                                    TextButton(
                                      onPressed: () => _viewDetails(context, s),
                                      child: const Text('View details'),
                                    ),
                                  ],
                                ),
                                if (stopDeals.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text(
                                        'Sponsored',
                                        style: TextStyle(color: Colors.amber),
                                      ),
                                      const SizedBox(width: 6),
                                      if (featured)
                                        const Icon(
                                          Icons.workspace_premium,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Deals:',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  for (final d in stopDeals.take(3))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('• ${d.title}'),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TruckStop {
  final String id;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final String tier; // 'free' | 'pro' | 'enterprise'

  const TruckStop({
    required this.id,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    required this.tier,
  });

  static TruckStop fromMap(Map<String, dynamic> row) => TruckStop(
    id: row['id'] as String,
    name: row['name'] as String,
    address: row['address'] as String?,
    lat: (row['lat'] as num).toDouble(),
    lng: (row['lng'] as num).toDouble(),
    tier: (row['tier'] as String?) ?? 'free',
  );
}

class TruckStopDeal {
  final String truckStopId;
  final String title;

  const TruckStopDeal({required this.truckStopId, required this.title});
}

class TruckStopParking {
  final String truckStopId;
  final int totalSpots;
  final int availableSpots;
  final DateTime? updatedAt;

  const TruckStopParking({
    required this.truckStopId,
    required this.totalSpots,
    required this.availableSpots,
    this.updatedAt,
  });
}

Widget _occupancyBadge(TruckStopParking p) {
  final ratio = p.totalSpots == 0 ? 0.0 : 1 - (p.availableSpots / p.totalSpots);
  Color color;
  String label;
  if (ratio < 0.33) {
    color = Colors.green;
    label = 'Low';
  } else if (ratio < 0.66) {
    color = Colors.orange;
    label = 'Med';
  } else {
    color = Colors.red;
    label = 'High';
  }
  return Chip(
    label: Text('Parking $label'),
    backgroundColor: color.withValues(alpha: 0.15),
  );
}

String _age(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ago';
}

class TruckStopService {
  final Ref ref;

  TruckStopService(this.ref);

  SupabaseClient? _maybe() {
    // Guard Supabase access using app config
    final cfg = ref.read(appConfigProvider);
    final configured =
        cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
    if (!configured) {
      debugPrint('Supabase client not ready');
      return null;
    }
    return Supabase.instance.client;
  }

  Future<List<TruckStop>> fetchTruckStops() async {
    final c = _maybe();
    if (c == null) return const <TruckStop>[];
    final rows = await c
        .from('truck_stops')
        .select('id,name,address,lat,lng,tier') // include tier
        .order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(TruckStop.fromMap)
        .toList();
  }

  Future<List<TruckStopDeal>> fetchActiveDeals() async {
    final c = _maybe();
    if (c == null) return const <TruckStopDeal>[];
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await c
        .from('truck_stop_deals')
        .select('truck_stop_id,title,valid_until,is_active')
        .eq('is_active', true)
        .or('valid_until.is.null,valid_until.gt.$nowIso')
        .limit(200);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => TruckStopDeal(
            truckStopId: row['truck_stop_id'] as String,
            title: row['title'] as String,
          ),
        )
        .toList();
  }

  Future<TruckStopParking?> latestParkingFor(String truckStopId) async {
    final c = _maybe();
    if (c == null) return null;
    final res = await c
        .from('truck_stop_parking')
        .select('total_spots,available_spots,updated_at')
        .eq('truck_stop_id', truckStopId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;

    return TruckStopParking(
      truckStopId: truckStopId,
      totalSpots: res['total_spots'] as int,
      availableSpots: res['available_spots'] as int,
      updatedAt: res['updated_at'] == null
          ? null
          : DateTime.tryParse(res['updated_at'] as String),
    );
  }

  Stream<TruckStopParking> parkingStream(String truckStopId) {
    final c = _maybe();
    if (c == null) {
      return const Stream.empty();
    }

    return c
        .from('truck_stop_parking')
        .stream(primaryKey: ['truck_stop_id', 'created_at'])
        .eq('truck_stop_id', truckStopId)
        .map((rows) {
          final row = rows.first;
          return TruckStopParking(
            truckStopId: truckStopId,
            totalSpots: row['total_spots'] as int,
            availableSpots: row['available_spots'] as int,
            updatedAt: row['updated_at'] == null
                ? null
                : DateTime.tryParse(row['updated_at'] as String),
          );
        });
  }
}

final truckStopServiceProvider = Provider<TruckStopService>((ref) {
  return TruckStopService(ref);
});
