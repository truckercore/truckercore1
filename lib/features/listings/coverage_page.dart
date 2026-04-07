import 'package:flutter/material.dart';

class CoveragePage extends StatelessWidget {
  const CoveragePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Coverage Area', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Configure radius or draw polygons (coming soon).'),
            const SizedBox(height: 12),
            Row(children: [
              const SizedBox(width: 220, child: TextField(decoration: InputDecoration(labelText: 'Radius (km)'), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: (){}, child: const Text('Save')),
            ]),
          ]),
        ),
      ),
    );
  }
}
