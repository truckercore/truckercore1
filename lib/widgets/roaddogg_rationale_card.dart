import 'package:flutter/material.dart';

class RoaddoggRationaleCard extends StatelessWidget {
  final String text; // pass the rationale string
  const RoaddoggRationaleCard({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.pets),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}
