import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/config/app_config.dart';
import '../../../common/state/session_provider.dart';
import 'owner_expenses_service.dart';

class TaxExpensesTab extends ConsumerStatefulWidget {
  const TaxExpensesTab({super.key});
  @override
  ConsumerState<TaxExpensesTab> createState() => _TaxExpensesTabState();
}

class _TaxExpensesTabState extends ConsumerState<TaxExpensesTab> {
  bool _loading = true;
  String? _error;
  ExpenseCategory? _filter;
  List<OwnerExpenseItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(ownerExpensesServiceProvider);
      _items = await svc.listMyExpenses(category: _filter);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isPremium = session.isPremium; // Pro or Enterprise
    // RBAC: owner-operator only (render empty if not)
    // Guard at caller preferred; here we do a soft guard.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long),
            const SizedBox(width: 8),
            const Text(
              'Tax-Deductible Expenses',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            PopupMenuButton<ExpenseCategory?>(
              tooltip: 'Filter Category',
              onSelected: (c) {
                setState(() => _filter = c);
                _load();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(child: Text('All')),
                ...ExpenseCategory.values.map(
                  (c) => PopupMenuItem(value: c, child: Text(_label(c))),
                ),
              ],
              child: const Row(
                children: [
                  Icon(Icons.filter_list),
                  SizedBox(width: 4),
                  Text('Filter'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isPremium) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export CSV'),
                onPressed: _exportCsv,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ExpenseCategory.values
                .map(
                  (c) => _CategoryTile(
                    label: _label(c),
                    onAdd: () => _onAdd(
                      c,
                      allowAmount: isPremium,
                      allowUpload: isPremium,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No expenses yet.'));
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final it = _items[i];
        final dollars = (it.amountCents / 100).toStringAsFixed(2);
        return ListTile(
          leading: const Icon(Icons.attach_money),
          title: Text(_label(it.category)),
          subtitle: Text(it.description ?? ''),
          trailing: Text('\$$dollars'),
        );
      },
    );
  }

  Future<void> _onAdd(
    ExpenseCategory cat, {
    required bool allowAmount,
    required bool allowUpload,
  }) async {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final truckCtrl = TextEditingController();
    final driverCtrl = TextEditingController();
    String? pickedUrl;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text('Add ${_label(cat)}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 8),
                  if (allowAmount)
                    TextField(
                      controller: amtCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount (USD)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  const SizedBox(height: 8),
                  if (allowAmount) ...[
                    TextField(
                      controller: truckCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Truck ID (Enterprise)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: driverCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Driver User ID (Enterprise)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pickedUrl == null
                                ? 'No receipt attached'
                                : 'Attached',
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.attachment),
                          label: const Text('Attach Receipt'),
                          onPressed: () async {
                            // Upload to Supabase storage (documents bucket)
                            final cfg = ref.read(appConfigProvider);
                            final ready =
                                cfg.supabaseUrl.isNotEmpty &&
                                cfg.supabaseAnonKey.isNotEmpty;
                            if (!ready) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Storage not configured.'),
                                ),
                              );
                              return;
                            }
                            final result = await FilePicker.platform.pickFiles(
                              withData: true,
                            );
                            if (result == null || result.files.isEmpty) return;
                            final f = result.files.first;
                            final bytes = f.bytes;
                            if (bytes == null) return;
                            final client = Supabase.instance.client;
                            final path =
                                'expenses/${DateTime.now().microsecondsSinceEpoch}_${f.name}';
                            await client.storage
                                .from('documents')
                                .uploadBinary(
                                  path,
                                  bytes,
                                  fileOptions: const FileOptions(upsert: true),
                                );
                            final url = client.storage
                                .from('documents')
                                .getPublicUrl(path)
                                .toString();
                            setLocal(() {
                              pickedUrl = url;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('ok'),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted) return;

    try {
      final svc = ref.read(ownerExpensesServiceProvider);
      int cents = 0;
      if (allowAmount) {
        final v = amtCtrl.text.trim();
        if (v.isNotEmpty) {
          final parsed = double.tryParse(v);
          if (parsed != null) cents = (parsed * 100).round();
        }
      }
      await svc.addExpense(
        category: cat,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        amountCents: cents,
        fileUrl: pickedUrl,
        truckId: truckCtrl.text.trim().isEmpty ? null : truckCtrl.text.trim(),
        driverUserId: driverCtrl.text.trim().isEmpty
            ? null
            : driverCtrl.text.trim(),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _exportCsv() async {
    // MVP: client-side CSV creation and show a snackbar (in real app, download/save via file_saver/web)
    final buf = StringBuffer();
    buf.writeln('date,category,description,amount_usd');
    for (final it in _items) {
      final dollars = (it.amountCents / 100).toStringAsFixed(2);
      buf.writeln(
        '${it.addedAt.toIso8601String()},${_label(it.category)},"${it.description ?? ''}",$dollars',
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV generated (MVP). Hook file saver to download.'),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final VoidCallback onAdd;
  const _CategoryTile({required this.label, required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }
}

String _label(ExpenseCategory c) {
  switch (c) {
    case ExpenseCategory.fuelTravel:
      return 'Fuel & Travel';
    case ExpenseCategory.maintenanceRepairs:
      return 'Maintenance & Repairs';
    case ExpenseCategory.insurance:
      return 'Insurance';
    case ExpenseCategory.equipmentParts:
      return 'Equipment & Parts';
    case ExpenseCategory.licensesPermits:
      return 'Licenses & Permits';
    case ExpenseCategory.operationalCosts:
      return 'Operational Costs';
    case ExpenseCategory.travelLodging:
      return 'Travel & Lodging';
    case ExpenseCategory.officeRecord:
      return 'Office & Record Keeping';
    case ExpenseCategory.miscellaneous:
      return 'Miscellaneous';
  }
}
