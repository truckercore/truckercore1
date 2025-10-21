import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters/time_format.dart';
import '../../dispatch/dispatch_controller.dart';

class RouteBoard extends ConsumerWidget {
  const RouteBoard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(dispatchControllerProvider);
    return LayoutBuilder(builder: (context, c){
      final wide = c.maxWidth>800;
      final Widget unassigned = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unassigned', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (st.unassigned.isEmpty) const Text('No unassigned loads for this window'),
          for(final l in st.unassigned)
            Card(child: ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: Text('${l.origin} → ${l.destination}'),
              subtitle: Text('Pickup ${fmtDateTime(l.pickup)}'),
              trailing: TextButton.icon(onPressed: () async {
                final id = await showDialog<String>(context: context, builder: (ctx)=> const _AssignDriverDialog());
                if (id!=null) ref.read(dispatchControllerProvider.notifier).assign(l.id, id);
              }, icon: const Icon(Icons.person_add_alt), label: const Text('Assign')),
            )),
        ],
      );
      final Widget assigned = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assigned', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (st.assigned.isEmpty) const Text('No assigned loads'),
          for(final entry in st.assigned.entries)
            Card(child: ExpansionTile(title: Text('Driver ${entry.key}'), children: [
              for(final l in entry.value)
                ListTile(leading: const Icon(Icons.local_shipping), title: Text('${l.origin} → ${l.destination}'), subtitle: Text('Pickup ${l.pickup}'))
            ])),
        ],
      );
      if (wide) {
        return Row(children: [
          Expanded(child: unassigned),
          const SizedBox(width: 12),
          Expanded(child: assigned),
        ]);
      }
      return ListView(
        children: [
          unassigned,
          const SizedBox(height: 12),
          assigned,
        ],
      );
    });
  }
}

class _AssignDriverDialog extends StatefulWidget {
  const _AssignDriverDialog();
  @override
  State<_AssignDriverDialog> createState() => _AssignDriverDialogState();
}
class _AssignDriverDialogState extends State<_AssignDriverDialog> {
  final _id = TextEditingController(text: 'D1');
  @override
  void dispose(){ _id.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context){
    return AlertDialog(
      title: const Text('Assign Driver'),
      content: SizedBox(width: 320, child: TextField(controller: _id, decoration: const InputDecoration(labelText: 'Driver ID', isDense: true))),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: ()=>Navigator.pop(context, _id.text.trim()), child: const Text('Assign')),
      ],
    );
  }
}
