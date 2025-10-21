import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GpsButton extends StatelessWidget {
  final String label;
  const GpsButton({super.key, this.label = 'View GPS Map'});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.public),
      label: Text(label),
      onPressed: () => context.push('/gps'),
    );
  }
}
