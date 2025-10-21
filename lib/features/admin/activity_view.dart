
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/services/supabase_client.dart';

class ActivityView extends ConsumerStatefulWidget {
  const ActivityView({super.key});

  @override
  ConsumerState<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends ConsumerState<ActivityView> {
  DateTimeRange? _dateRange;
  String? _userId;
  String? _action;
  int _page = 0;
  bool _loading = false;
  List<dynamic> _rows = [];
  int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final client = ref.read(supabaseClientProvider);
    setState(() => _loading = true);
    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;
      // Build filters first, then apply order/range (Supabase Dart chaining semantics)
      var q = client.from('v_enterprise_activity').select();
      if (_dateRange != null) {
        q = q.filter('occurred_at', 'gte', _dateRange!.start.toUtc().toIso8601String());
        q = q.filter('occurred_at', 'lte', _dateRange!.end.toUtc().toIso8601String());
      }
      if (_userId != null && _userId!.isNotEmpty) {
        q = q.filter('actor_user_id', 'eq', _userId);
      }
      if (_action != null && _action!.isNotEmpty) {
        q = q.filter('action', 'eq', _action);
      }
      final res = await q.order('occurred_at', ascending: false).range(from, to);
      setState(() => _rows = res as List<dynamic>);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    final client = ref.read(supabaseClientProvider);
    try {
      var q = client.from('v_enterprise_activity').select();
      if (_dateRange != null) {
        q = q.filter('occurred_at', 'gte', _dateRange!.start.toUtc().toIso8601String());
        q = q.filter('occurred_at', 'lte', _dateRange!.end.toUtc().toIso8601String());
      }
      if (_userId != null && _userId!.isNotEmpty) {
        q = q.filter('actor_user_id', 'eq', _userId);
      }
      if (_action != null && _action!.isNotEmpty) {
        q = q.filter('action', 'eq', _action);
      }
      final res = await q.order('occurred_at', ascending: false);
      final rows = (res as List<dynamic>).cast<Map<String, dynamic>>();
      final csv = _toCsv(rows);
      // For now, simply show in a dialog for copy. Real app could save/share.
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('CSV Export (copy)'),
          content: SingleChildScrollView(child: SelectableText(csv)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _toCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';
    final headers = [
      'occurred_at', 'actor_user_id', 'action', 'entity_type', 'entity_id', 'description', 'trace_id', 'record_hash', 'prev_hash'
    ];
    final sb = StringBuffer();
    sb.writeln(headers.join(','));
    for (final r in rows) {
      final vals = headers.map((h) => _csvEscape(r[h]));
      sb.writeln(vals.join(','));
    }
    return sb.toString();
  }

  String _csvEscape(dynamic v) {
    var s = v == null ? '' : v.toString();
    if (s.contains(',') || s.contains('\n') || s.contains('"')) {
      s = '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(onPressed: _exportCsv, icon: const Icon(Icons.download)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Filters(
              onApply: (range, userId, action, pageSize) {
                _dateRange = range;
                _userId = userId;
                _action = action;
                _pageSize = pageSize;
                _page = 0;
                _fetch();
              },
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final r = _rows[i] as Map<String, dynamic>;
                        return ListTile(
                          dense: true,
                          title: Text('${r['action']} — ${r['entity_type']}:${r['entity_id']}'),
                          subtitle: Text(r['description'] ?? ''),
                          trailing: Text((r['occurred_at'] ?? '').toString()),
                        );
                      },
                    ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _page > 0 ? () { setState(() => _page -= 1); _fetch(); } : null,
                  child: const Text('Prev'),
                ),
                Text('Page ${_page + 1}'),
                TextButton(
                  onPressed: _rows.length == _pageSize ? () { setState(() => _page += 1); _fetch(); } : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatefulWidget {
  final void Function(DateTimeRange?, String?, String?, int pageSize) onApply;
  const _Filters({required this.onApply});

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  DateTimeRange? _range;
  final _userCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  int _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 1),
                initialDateRange: _range,
              );
              if (picked != null) setState(() => _range = picked);
            },
            child: Text(_range == null ? 'Date Range' : '${_range!.start.toString().split(' ').first} → ${_range!.end.toString().split(' ').first}'),
          ),
          SizedBox(width: 160, child: TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'User ID'))),
          SizedBox(width: 160, child: TextField(controller: _actionCtrl, decoration: const InputDecoration(labelText: 'Action'))),
          DropdownButton<int>(
            value: _pageSize,
            items: const [20, 30, 50].map((e) => DropdownMenuItem(value: e, child: Text('$e/page'))).toList(),
            onChanged: (v) => setState(() => _pageSize = v ?? 20),
          ),
          ElevatedButton(
            onPressed: () => widget.onApply(_range, _userCtrl.text.isEmpty ? null : _userCtrl.text, _actionCtrl.text.isEmpty ? null : _actionCtrl.text, _pageSize),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
