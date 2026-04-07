// lib/features/matching/load_matching_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/services/loads_service.dart';
import 'services/matching_service.dart';

class LoadMatchingPanel extends ConsumerStatefulWidget {
  const LoadMatchingPanel({super.key});

  @override
  ConsumerState<LoadMatchingPanel> createState() => _LoadMatchingPanelState();
}

class _LoadMatchingPanelState extends ConsumerState<LoadMatchingPanel> {
  bool _loading = false;
  List<LoadMatch> _matches = const [];
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
      final svc = ref.read(matchingServiceProvider);
      _matches = await svc.getSuggestions();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign(LoadMatch m) async {
    final loads = ref.read(loadsServiceProvider);
    try {
      await loads.assignDriver(
        loadId: m.loadId,
        driverUserId: m.suggestionDriverId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Driver assigned')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Assign failed: $e')));
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
    if (_matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'No suggestions (all loads assigned or no available drivers).',
        ),
      );
    }

    return Column(
      children: _matches.map((m) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: Text('Suggested driver: ${_short(m.suggestionDriverId)}'),
            subtitle: Text(
              'Score: ${m.score.toStringAsFixed(1)} • ${m.rationale}',
            ),
            trailing: ElevatedButton(
              onPressed: () => _assign(m),
              child: const Text('Assign'),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _short(String id) => id.length > 8 ? '${id.substring(0, 8)}…' : id;
}
