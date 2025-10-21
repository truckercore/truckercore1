import 'package:flutter/material.dart';

class RoiCalculator extends StatefulWidget {
  const RoiCalculator({super.key});

  @override
  State<RoiCalculator> createState() => _RoiCalculatorState();
}

class _RoiCalculatorState extends State<RoiCalculator> {
  final _fleetSize = TextEditingController(text: '100');
  final _fuelPrice = TextEditingController(text: '4.00');
  final _loadsPerMo = TextEditingController(text: '200');
  final _detentionHrs = TextEditingController(text: '300');
  final _onTime = TextEditingController(text: '90'); // %

  double? _annualRoiPct;
  double? _annualSavings;
  double? _annualCost;

  void _calc() {
    final fleet = int.tryParse(_fleetSize.text) ?? 0;
    final fuelPrice = double.tryParse(_fuelPrice.text) ?? 0;
    final loadsMo = int.tryParse(_loadsPerMo.text) ?? 0;
    final detentionHrs = double.tryParse(_detentionHrs.text) ?? 0;
    final onTimePct = (double.tryParse(_onTime.text) ?? 0) / 100.0;

    // Assumptions
    final avgMilesPerTruckYear = 100000.0;
    final fleetMiles = fleet * avgMilesPerTruckYear;

    final fuelSavings = fleetMiles * fuelPrice * 0.05; // 5% routing savings
    final detentionSavings = detentionHrs * 75.0 * 0.2; // 20% reduction
    final automationHoursSaved = loadsMo * 12 * 0.25; // 0.25h per load saved
    final automationSavings = automationHoursSaved * 35.0; // $35/hr
    final onTimeImprove =
        mathClampDouble((onTimePct + 0.03) * 100, 0, 100) - (onTimePct * 100);
    // Monetize on-time improvement as fewer penalties/chargebacks: assume $50 impact per load per 1% point improvement
    final onTimeSavings = loadsMo * 12 * 50.0 * (onTimeImprove / 100.0);

    final savings =
        fuelSavings + detentionSavings + automationSavings + onTimeSavings;
    final subscription = fleet * 50.0 * 12; // $50/driver/mo example
    final roiPct = ((savings - subscription) / subscription) * 100.0;

    setState(() {
      _annualSavings = savings;
      _annualCost = subscription;
      _annualRoiPct = roiPct;
    });
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const ListTile(title: Text('ROI Calculator')),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fleetSize,
                    decoration: deco('Fleet size'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fuelPrice,
                    decoration: deco('Avg fuel \$/gal'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _loadsPerMo,
                    decoration: deco('Avg loads/mo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _detentionHrs,
                    decoration: deco('Detention hrs/yr'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _onTime,
                    decoration: deco('On-time %'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _calc, child: const Text('Compute')),
              ],
            ),
            if (_annualSavings != null) const Divider(),
            if (_annualSavings != null)
              ListTile(
                title: const Text('Results'),
                subtitle: Text(
                  'Savings: \$${_annualSavings!.toStringAsFixed(0)} /yr\n'
                  'Subscription: \$${_annualCost!.toStringAsFixed(0)} /yr\n'
                  'ROI: ${_annualRoiPct!.toStringAsFixed(0)}%',
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Export coming soon. Contact sales.'),
                      ),
                    );
                  },
                  child: const Text('Export PDF'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

double mathClampDouble(double v, double min, double max) =>
    v < min ? min : (v > max ? max : v);
