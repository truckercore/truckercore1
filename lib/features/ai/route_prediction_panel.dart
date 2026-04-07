// lib/features/ai/route_prediction_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/route_prediction_service.dart';

class RoutePredictionPanel extends ConsumerStatefulWidget {
  const RoutePredictionPanel({super.key});

  @override
  ConsumerState<RoutePredictionPanel> createState() =>
      _RoutePredictionPanelState();
}

class _RoutePredictionPanelState extends ConsumerState<RoutePredictionPanel> {
  bool _loading = false;
  List<RoutePrediction> _items = const [];
  String? _error;

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
      final svc = ref.read(routePredictionServiceProvider);
      _items = await svc.getForecasts();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Error: $_error'),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No active loads or all loads are on track.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._items
            .take(5)
            .map(
              (p) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Icon(
                    p.atRisk ? Icons.warning_amber : Icons.check_circle_outline,
                    color: p.atRisk ? Colors.amber : Colors.green,
                  ),
                  title: Text('${p.origin} → ${p.destination}'),
                  subtitle: Text(
                    'ETA: ~${_fmtDur(p.eta)} • Slack: ${_fmtDur(p.slack)}\n${p.rationale}',
                  ),
                  isThreeLine: true,
                  trailing: p.atRisk
                      ? ElevatedButton.icon(
                          icon: const Icon(Icons.alt_route),
                          label: const Text('Suggest reroute'),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reroute suggestion coming soon'),
                              ),
                            );
                          },
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
            label: const Text('Recompute'),
          ),
        ),
      ],
    );
  }

  String _fmtDur(Duration d) {
    final sign = d.isNegative ? '-' : '';
    final dd = d.abs();
    final h = dd.inHours;
    final m = dd.inMinutes.remainder(60);
    return '$sign${h}h ${m}m';
  }
}
