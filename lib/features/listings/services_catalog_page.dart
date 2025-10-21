import 'package:flutter/material.dart';

class ServicesCatalogPage extends StatelessWidget {
  const ServicesCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: bind to roadside_services table
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Services Offered', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Wrap(spacing: 8, children: [
              FilterChip(label: Text('Tow'), selected: true, onSelected: null),
              FilterChip(label: Text('Tire'), selected: true, onSelected: null),
              FilterChip(label: Text('Jump'), onSelected: null),
              FilterChip(label: Text('Lockout'), onSelected: null),
              FilterChip(label: Text('Light Repair'), selected: true, onSelected: null),
            ]),
            const SizedBox(height: 12),
            const Text('Typical ETA (minutes)'),
            const SizedBox(height: 6),
            const SizedBox(
              width: 220,
              child: TextField(decoration: InputDecoration(labelText: 'ETA'), keyboardType: TextInputType.number),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(onPressed: (){}, child: const Text('Save')),
            )
          ]),
        ),
      ),
    );
  }
}
