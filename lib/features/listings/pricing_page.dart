import 'package:flutter/material.dart';

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pricing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const SizedBox(width: 260, child: TextField(decoration: InputDecoration(labelText: 'Base Fee (cents)'), keyboardType: TextInputType.number)),
            const SizedBox(height: 8),
            const SizedBox(width: 260, child: TextField(decoration: InputDecoration(labelText: 'Per Mile (cents)'), keyboardType: TextInputType.number)),
            const SizedBox(height: 8),
            const SizedBox(width: 260, child: TextField(decoration: InputDecoration(labelText: 'After-hours Multiplier'), keyboardType: TextInputType.number)),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: (){}, child: const Text('Save')))
          ]),
        ),
      ),
    );
  }
}
