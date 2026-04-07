// lib/features/geofencing/geofence_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truckercore1/features/connectivity/connectivity_provider.dart';

import '../../common/widgets/error_card.dart';
import '../../common/widgets/section_header.dart';
import '../../common/widgets/skeleton_list.dart';
import 'services/geofencing_service.dart';

class GeofencePanel extends ConsumerStatefulWidget {
  const GeofencePanel({super.key});

  @override
  ConsumerState<GeofencePanel> createState() => _GeofencePanelState();
}

class _GeofencePanelState extends ConsumerState<GeofencePanel> {
  bool _loading = false;
  String? _error;
  List<GeofenceEvent> _items = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await ref.read(geofenceServiceProvider).recent(take: 10);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityStatusProvider);

    // Header row with shared SectionHeader
    final header = SectionHeader(
      title: 'Recent Geofence Events',
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: isOnline && !_loading ? _refresh : null,
        icon: const Icon(Icons.refresh),
      ),
    );

    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 8),
          const SkeletonList(),
        ],
      );
    }
    // ... existing code ...
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 8),
          ErrorCard(
            message: 'Failed to load: $_error',
            onRetry: isOnline ? _refresh : null,
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF34D399)),
                SizedBox(width: 8),
                Text('No recent yard entries/exits.'),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 8),
        ..._items.map(
          (e) => Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: _icon(e),
              title: Text('${e.truckId} • ${e.geofenceName}'),
              subtitle: Text(_subtitle(e)),
              trailing: e.event == 'in'
                  ? TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Assign dock bay coming soon'),
                          ),
                        );
                      },
                      child: const Text('Assign Dock'),
                    )
                  : null,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }

  Widget _icon(GeofenceEvent e) {
    final color = e.event == 'in' ? Colors.green : Colors.blueGrey;
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(e.event == 'in' ? Icons.login : Icons.logout, color: color),
    );
  }

  String _subtitle(GeofenceEvent e) {
    final tsLocal = e.ts.toLocal();
    if (e.event == 'out' && e.dwell != null) {
      final h = e.dwell!.inHours;
      final m = e.dwell!.inMinutes.remainder(60);
      return 'Exited • $tsLocal\nDwell: ${h}h ${m}m';
    }
    return '${e.event == 'in' ? 'Entered' : 'Exited'} • $tsLocal';
  }
}
