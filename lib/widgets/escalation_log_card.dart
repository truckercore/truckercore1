import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/supabase/client.dart';
import '../ui/empty_state.dart';
import '../ui/theming.dart';

class EscalationLogCard extends StatefulWidget {
  final String title;
  final ColorScheme? colorSchemeOverride;
  final int pageSize;

  const EscalationLogCard({
    super.key,
    this.title = 'Escalations',
    this.colorSchemeOverride,
    this.pageSize = 25,
  });

  @override
  State<EscalationLogCard> createState() => _EscalationLogCardState();
}

class _EscalationLogCardState extends State<EscalationLogCard> {
  final _items = <Map<String, dynamic>>[];
  bool _loading = false;
  bool _end = false;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _fetchMore();
  }

  Future<void> _fetchMore() async {
    if (_loading || _end) return;
    setState(() => _loading = true);
    final page = await TC.selectPage(
      from: 'escalation_logs',
      orderBy: 'created_at',
      offset: _offset,
      limit: widget.pageSize,
    );
    if (page.length < widget.pageSize) _end = true;
    _offset += page.length;
    _items.addAll(page);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = _items.isEmpty && !_loading
        ? const EmptyState(
            title: 'No escalations logged — system is healthy 🎉',
            tip: 'When alerts are escalated, they’ll show up here with status, owner, and links.',
          )
        : NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (!_end && !_loading && n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
                _fetchMore();
              }
              return false;
            },
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _items.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final row = _items[i];
                final alertId = row['alert_id'] as String?;
                final status = row['status'] as String?;
                final owner = row['owner_name'] as String?;
                final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');

                return ListTile(
                  leading: Icon(
                    status == 'open' ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                    color: status == 'open' ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                  title: Text(row['title'] ?? 'Escalation'),
                  subtitle: Text([
                    if (owner != null) 'Owner: $owner',
                    if (status != null) 'Status: $status',
                    if (createdAt != null) 'At: ${createdAt.toLocal()}',
                  ].join(' • ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: alertId == null
                      ? null
                      : () {
                          context.push('/alerts/$alertId');
                        },
                );
              },
            ),
          );

    return CardThemeWrapper(
      colorSchemeOverride: widget.colorSchemeOverride,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(widget.title, style: theme.textTheme.titleMedium),
              ),
              const Divider(height: 1),
              body,
            ],
          ),
        ),
      ),
    );
  }
}
