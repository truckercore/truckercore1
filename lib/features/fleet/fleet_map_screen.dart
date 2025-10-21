import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../offline/offline_downloads_service.dart';
import 'services/telemetry_service.dart';

class FleetMapScreen extends ConsumerStatefulWidget {
  const FleetMapScreen({super.key});
  @override
  ConsumerState<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends ConsumerState<FleetMapScreen> {
  LatLng _toLatLng(TruckPosition p) => LatLng(p.lat, p.lng);
  final TextEditingController _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryServiceProvider);
    const centerFallback = LatLng(39.5, -98.35);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Map'),
        actions: [
          IconButton(
            tooltip: 'Map settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openOfflineDownloadsSheet(context, ref),
          ),
        ],
      ),
      body: FutureBuilder<List<TruckPosition>>(
        future: telemetry.listCurrentPositions(),
        builder: (context, snapshot) {
          final initial = snapshot.data ?? const <TruckPosition>[];
          final initialCenter = initial.isNotEmpty
              ? _toLatLng(initial.first)
              : centerFallback;
          final initialZoom = initial.isNotEmpty ? 6.0 : 4.0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search driver/asset',
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<TruckPosition>(
                  stream: telemetry.streamCurrentPositions(),
                  builder: (context, streamSnap) {
                    final updates = <TruckPosition>[];
                    if (streamSnap.hasData) updates.add(streamSnap.data!);

                    // Merge: latest by truckId
                    final byId = <String, TruckPosition>{
                      for (final p in initial) p.truckId: p,
                    };
                    for (final u in updates) {
                      byId[u.truckId] = u;
                    }
                    var positions = byId.values.toList();
                    final q = _search.text.trim().toLowerCase();
                    if (q.isNotEmpty) {
                      positions = positions
                          .where((p) => p.truckId.toLowerCase().contains(q))
                          .toList();
                    }

                    final markers = positions.map((p) {
                      final color = p.health == 'moving'
                          ? Colors.green
                          : p.health == 'idle'
                          ? Colors.amber
                          : Colors.grey;
                      return Marker(
                        point: _toLatLng(p),
                        width: 44,
                        height: 44,
                        child: Column(
                          children: [
                            Icon(Icons.local_shipping, color: color, size: 28),
                            Text(
                              p.truckId.substring(0, 6),
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList();

                    return FlutterMap(
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: initialZoom,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.truckercore.app',
                        ),
                        // Use cluster layer if plugin available; fallback to markers
                        MarkerLayer(markers: markers),
                      ],
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


Future<void> _openOfflineDownloadsSheet(BuildContext context, WidgetRef ref) async {
  final service = ref.read(offlineDownloadsServiceProvider);
  final regions = await service.listRegions();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final controller = ScrollController();
      final samples = const [
        'Northeast_US',
        'Midwest_US',
        'Southeast_US',
        'Southwest_US',
        'West_US',
      ];
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download_for_offline_outlined),
                const SizedBox(width: 8),
                Text(
                  'Offline downloads',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Help',
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Choose a region to store basic tiles + POIs for offline use.',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Scrollbar(
                controller: controller,
                child: ListView.builder(
                  controller: controller,
                  shrinkWrap: true,
                  itemCount: samples.length,
                  itemBuilder: (ctx, i) {
                    final key = samples[i];
                    final isDownloaded = regions.contains(key);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(key),
                      subtitle: Text(
                        isDownloaded
                            ? 'Downloaded • tiles+POIs (stub)'
                            : 'Not downloaded • ~40–120 MB (stub)'
                      ),
                      trailing: isDownloaded
                          ? TextButton.icon(
                              onPressed: () async {
                                await service.removeRegion(key);
                                if (context.mounted) Navigator.pop(context);
                                // reopen to refresh
                                if (context.mounted) {
                                  _openOfflineDownloadsSheet(context, ref);
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove'),
                            )
                          : ElevatedButton.icon(
                              onPressed: () async {
                                // Stub: mark as downloaded
                                await service.addRegion(key);
                                if (context.mounted) Navigator.pop(context);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Downloaded $key (stub)')),
                                  );
                                  _openOfflineDownloadsSheet(context, ref);
                                }
                              },
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Download'),
                            ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Icon(Icons.info_outline, size: 16),
                  Text('This is a stub. Actual tile/POI downloads will be wired later.'),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
