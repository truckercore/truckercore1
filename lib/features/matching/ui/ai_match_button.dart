import 'package:flutter/material.dart';

import '../../../common/gating/feature_gate.dart';
import '../../../features/paywall/paywall_card.dart';
// import '../../drivers/data/driver_repository.dart'; // optional: if you have one; else stub name lookup
import '../data/match_repository.dart';

typedef AssignCallback = Future<void> Function(String driverUserId);

class AiMatchDriversPanel extends StatefulWidget {
  final String loadId;
  final AssignCallback onAssign;

  const AiMatchDriversPanel({
    super.key,
    required this.loadId,
    required this.onAssign,
  });

  @override
  State<AiMatchDriversPanel> createState() => _AiMatchDriversPanelState();
}

class _AiMatchDriversPanelState extends State<AiMatchDriversPanel> {
  bool _busy = false;
  List<DriverMatch> _items = [];
  final _repo = MatchRepository();

  Future<void> _run() async {
    final ctx = context;
    setState(() => _busy = true);
    try {
      final results = await _repo.runMatch(loadId: widget.loadId);
      setState(() => _items = results);
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('Match error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: FeatureGate.has('ai_match'),
      builder: (context, snap) {
        final allowed = snap.data == true;
        if (!allowed) {
          // Paywall visible; log impression
          FeatureGate.logPaywall('ai_match');
          return const PaywallCard(
            title: 'AI Match (Pro)',
            description:
                'Unlock AI driver matching with rationale and scoring.',
          );
        }
        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _run,
                icon: const Icon(Icons.auto_awesome),
                label: _busy
                    ? const Text('Matching...')
                    : const Text('AI Match Drivers'),
              ),
            ),
            const SizedBox(height: 8),
            if (_items.isNotEmpty)
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Driver Matches'),
                      subtitle: Text('${_items.length} candidates'),
                    ),
                    const Divider(height: 1),
                    ..._items.map(
                      (m) => _DriverRow(match: m, onAssign: widget.onAssign),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DriverRow extends StatelessWidget {
  final DriverMatch match;
  final AssignCallback onAssign;

  const _DriverRow({required this.match, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(match.driverUserId),
      subtitle: Text(match.rationale),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            match.score.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => onAssign(match.driverUserId),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}
