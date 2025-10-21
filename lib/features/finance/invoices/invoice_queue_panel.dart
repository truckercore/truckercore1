import 'package:flutter/material.dart';

class InvoiceQueuePanel extends StatelessWidget {
  final List<Map<String, dynamic>> items; // supply from REST view later
  const InvoiceQueuePanel({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(child: ListTile(title: Text('No invoices pending')));
    }
    return Card(
      child: Column(
        children: items
            .map(
              (e) => ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text('Load ${e['load_id']} • \$${e['amount']}'),
                subtitle: Text('Status: ${e['status']} • ${e['updated_at']}'),
                trailing: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Export 210'),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
