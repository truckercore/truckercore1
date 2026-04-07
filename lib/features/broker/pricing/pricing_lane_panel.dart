import 'package:flutter/material.dart';
import '../../../services/pricing_rates_service.dart';

class PricingLanePanel extends StatefulWidget {
  final PricingRatesService rates;
  final String lane; // "Dallas, TX → Atlanta, GA"
  final String equipment; // 'dry van' | ...
  final String brokerId;
  const PricingLanePanel({
    super.key,
    required this.rates,
    required this.lane,
    required this.equipment,
    required this.brokerId,
  });
  @override
  State<PricingLanePanel> createState() => _PricingLanePanelState();
}

class _PricingLanePanelState extends State<PricingLanePanel> {
  late Future<List<Map<String, dynamic>>> _futureRates;
  late Future<List<Map<String, dynamic>>> _futureCredit;

  @override
  void initState() {
    super.initState();
    _futureRates = widget.rates.dailyLaneRates(
      lane: widget.lane,
      equipment: widget.equipment,
    );
    _futureCredit = widget.rates.brokerCredit(widget.brokerId);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lane ${widget.lane} • ${widget.equipment}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder(
              future: Future.wait([_futureRates, _futureCredit]),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rates =
                    (snap.data as List)[0] as List<Map<String, dynamic>>;
                final credit =
                    (snap.data as List)[1] as List<Map<String, dynamic>>;
                final r0 = rates.isNotEmpty ? rates.first : null;
                final p50 = r0?['p50'];
                final p80 = r0?['p80'];
                final conf = r0?['confidence'];
                final badge = credit.isNotEmpty
                    ? (credit.first['tier'] ?? 'B')
                    : 'B';
                final src = r0?['source'];
                final dateStr = (r0?['date']?.toString() ?? '')
                    .split('T')
                    .first;
                final lowConf = (conf is num) && conf < 0.3;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Today p50: ${p50 ?? 'n/a'}  •  p80: ${p80 ?? 'n/a'}',
                        ),
                        if (src != null) Chip(label: Text('Source: $src')),
                        Chip(label: Text('Conf: ${conf ?? 'n/a'}')),
                        if (lowConf)
                          const Chip(
                            label: Text('Low confidence'),
                            backgroundColor: Colors.orangeAccent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (dateStr.isNotEmpty)
                          Text(
                            'Last updated: $dateStr',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            setState(() {
                              _futureRates = widget.rates.dailyLaneRates(
                                lane: widget.lane,
                                equipment: widget.equipment,
                              );
                              _futureCredit = widget.rates.brokerCredit(
                                widget.brokerId,
                              );
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Updated just now'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Chip(label: Text('Broker credit: $badge')),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
