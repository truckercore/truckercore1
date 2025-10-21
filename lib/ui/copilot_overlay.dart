import 'package:flutter/material.dart';

class CopilotOverlay extends StatelessWidget {
  final DateTime violationEta; final DateTime recommendedAt; final String? parkingName;
  const CopilotOverlay({super.key, required this.violationEta, required this.recommendedAt, this.parkingName});
  @override Widget build(BuildContext context){
    final minsToBreak = recommendedAt.difference(DateTime.now()).inMinutes;
    return Card(margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(16), child:
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Next rest in ~$minsToBreak min', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        if (parkingName!=null) Text('Suggested parking: $parkingName'),
        Text('Violation ETA: ${violationEta.toLocal()}'),
        const SizedBox(height:8),
        Row(children:[
          ElevatedButton(onPressed:(){}, child: const Text('Navigate')),
          const SizedBox(width:8),
          OutlinedButton(onPressed:(){}, child: const Text('Snooze 15m')),
        ])
      ])
    ));
  }
}
