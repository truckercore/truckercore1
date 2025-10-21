import 'package:flutter/material.dart';
import '../../../services/bid_assist_service.dart';

class BidAssistButton extends StatefulWidget {
  final BidAssistService svc;
  final String origin, destination, equipment;
  final DateTime pickupAtUtc;
  final String? driverId;
  const BidAssistButton({
    super.key,
    required this.svc,
    required this.origin,
    required this.destination,
    required this.equipment,
    required this.pickupAtUtc,
    this.driverId,
  });

  @override
  State<BidAssistButton> createState() => _BidAssistButtonState();
}

class _BidAssistButtonState extends State<BidAssistButton> {
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    final tStart = DateTime.now();
    try {
      final out = await widget.svc.suggestBid(
        origin: widget.origin,
        destination: widget.destination,
        equipment: widget.equipment,
        pickupAtUtc: widget.pickupAtUtc,
        driverId: widget.driverId,
      );
      final ms = DateTime.now().difference(tStart).inMilliseconds;
      // Lightweight latency log (MVP)
      // ignore: avoid_print
      print(
        '[bid_assist] latency_ms=$ms lane=${widget.origin}->${widget.destination}',
      );
      if (!mounted) {
        return;
      }
      showDialog(
        context: context,
        builder: (ctx) {
          final t = out['target_band'] ?? {};
          final s = out['suggested_bid'];
          final why = (out['rationale'] as List?)?.cast<String>() ?? const [];
          final adj = (out['adjustments'] as Map?) ?? const {};
          final hosOk = adj['hos_ok'] != false;
          return AlertDialog(
            title: const Text('Bid Assist'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target: p50 \$${t['p50'] ?? 'n/a'}  •  p80 \$${t['p80'] ?? 'n/a'}',
                ),
                const SizedBox(height: 6),
                Text('Suggested bid: ${s == null ? 'n/a' : '\$$s'}'),
                if (!hosOk) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Driver HOS may be tight for this pickup window. Consider a different driver or adjust pickup time.',
                    ),
                  ),
                ],
                const Divider(),
                const Text(
                  'Why this suggestion?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...why.map((e) => Text('• $e')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : _run,
      icon: const Icon(Icons.attach_money),
      label: Text(_loading ? 'Calculating…' : 'Bid Assist'),
    );
  }
}
