import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  const KpiCard({super.key, required this.title, required this.value, this.subtitle = ''});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ),
      );
}
