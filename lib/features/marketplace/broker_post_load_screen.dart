import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/ai_finance_service.dart';
import '../../services/marketplace_service.dart';

class BrokerPostLoadScreen extends ConsumerStatefulWidget {
  const BrokerPostLoadScreen({super.key});
  @override
  ConsumerState<BrokerPostLoadScreen> createState() =>
      _BrokerPostLoadScreenState();
}

class _BrokerPostLoadScreenState extends ConsumerState<BrokerPostLoadScreen> {
  final _origin = TextEditingController();
  final _dest = TextEditingController();
  DateTime? _pickup;
  DateTime? _drop;
  final _pay = TextEditingController();
  String _equip = 'dry_van';
  bool _busy = false;
  String? _msg;

  Future<void> _submit() async {
    final origin = _origin.text.trim();
    final dest = _dest.text.trim();
    final payUsd = double.tryParse(_pay.text.trim()) ?? 0;
    if (origin.isEmpty ||
        dest.isEmpty ||
        _pickup == null ||
        _drop == null ||
        payUsd <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill all fields')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceServiceProvider)
          .postLoad(
            origin: origin,
            destination: dest,
            pickupAt: _pickup!,
            dropoffAt: _drop!,
            payCents: (payUsd * 100).round(),
            equipment: _equip,
          );
      if (!mounted) return;
      setState(() => _msg = 'Posted');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Load posted')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = 'Failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Load')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _origin,
            decoration: const InputDecoration(
              labelText: 'Origin',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dest,
            decoration: const InputDecoration(
              labelText: 'Destination',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _pickup == null ? 'Pickup' : _pickup!.toLocal().toString(),
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 180)),
                    initialDate: now,
                  );
                  if (d != null) setState(() => _pickup = d);
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _drop == null ? 'Dropoff' : _drop!.toLocal().toString(),
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 180)),
                    initialDate: now,
                  );
                  if (d != null) setState(() => _drop = d);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _pay,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pay (USD)',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _equip,
            items: const [
              DropdownMenuItem(value: 'dry_van', child: Text('Dry Van')),
              DropdownMenuItem(value: 'reefer', child: Text('Reefer')),
              DropdownMenuItem(value: 'flatbed', child: Text('Flatbed')),
            ],
            onChanged: (v) => setState(() => _equip = v ?? _equip),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Post'),
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Negotiation Helper'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const _NegotiationHelperDialog(),
              );
            },
          ),
          if (_msg != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!)),
        ],
      ),
    );
  }
}

class _NegotiationHelperDialog extends ConsumerStatefulWidget {
  const _NegotiationHelperDialog();
  @override
  ConsumerState<_NegotiationHelperDialog> createState() =>
      _NegotiationHelperDialogState();
}

class _NegotiationHelperDialogState
    extends ConsumerState<_NegotiationHelperDialog> {
  late Future<List<AiFinancialRecommendation>> _future;
  @override
  void initState() {
    super.initState();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    _future = uid == null
        ? Future.value(const [])
        : ref.read(aiFinanceServiceProvider).lastRecsForUser(uid, limit: 5);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Negotiation Helper'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<AiFinancialRecommendation>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final rows = snap.data!;
            if (rows.isEmpty) {
              return const Text('No tips yet.');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent tips:'),
                const SizedBox(height: 6),
                ...rows.map(
                  (r) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.lightbulb_outline),
                    title: Text(r.text),
                    subtitle: Text(
                      'Savings: \$${(r.projectedSavingsCents / 100).toStringAsFixed(0)}',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
