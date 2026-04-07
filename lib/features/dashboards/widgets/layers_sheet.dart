import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _trafficProvider = StateProvider<bool>((_) => true);
final _weatherProvider = StateProvider<bool>((_) => false);

/// Floating button that opens a bottom sheet to toggle map layers.
/// Persists simple toggles using SharedPreferences.
class LayersSheetButton extends ConsumerWidget {
  const LayersSheetButton({super.key});

  Future<void> _persist(bool traffic, bool weather) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('layers.traffic', traffic);
      await sp.setBool('layers.weather', weather);
    } catch (_) {}
  }

  Future<void> _load(WidgetRef ref) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final t = sp.getBool('layers.traffic');
      final w = sp.getBool('layers.weather');
      if (t != null) ref.read(_trafficProvider.notifier).state = t;
      if (w != null) ref.read(_weatherProvider.notifier).state = w;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      heroTag: 'layers_fab',
      onPressed: () {
        _load(ref); // fire-and-forget
        final traffic = ref.read(_trafficProvider);
        final weather = ref.read(_weatherProvider);
        showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Layers', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Traffic'),
                  value: traffic,
                  onChanged: (v) {
                    ref.read(_trafficProvider.notifier).state = v;
                    _persist(v, ref.read(_weatherProvider));
                  },
                ),
                SwitchListTile(
                  title: const Text('Weather'),
                  value: weather,
                  onChanged: (v) {
                    ref.read(_weatherProvider.notifier).state = v;
                    _persist(ref.read(_trafficProvider), v);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done'),
                  ),
                )
              ],
            ),
          ),
        );
      },
      icon: const Icon(Icons.layers),
      label: const Text('Layers'),
    );
  }
}
