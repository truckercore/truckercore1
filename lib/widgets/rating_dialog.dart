import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showRateBrokerDialog(BuildContext context, {required String brokerId, required String loadId}) async {
  final c = Supabase.instance.client;
  final orgId = c.auth.currentUser?.userMetadata?['org_id'];
  final userId = c.auth.currentUser?.id;
  int rating = 5;
  final notesCtrl = TextEditingController();

  await showDialog(context: context, builder: (_) {
    return AlertDialog(
      title: const Text('Rate broker'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButton<int>(
          value: rating,
          onChanged: (v){ rating = v ?? 5; },
          items: List.generate(5, (i)=>DropdownMenuItem(value: i+1, child: Text('${i+1}'))),
        ),
        TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)')),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          await c.from('broker_ratings').insert({
            'org_id': orgId, 'user_id': userId, 'broker_id': brokerId, 'load_id': loadId,
            'rating': rating, 'notes': notesCtrl.text
          });
          if (context.mounted) Navigator.pop(context);
        }, child: const Text('Submit')),
      ],
    );
  });
}
