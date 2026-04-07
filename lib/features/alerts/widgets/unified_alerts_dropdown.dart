import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truckercore1/features/alerts/alerts_feed_service.dart';

class UnifiedAlertsDropdown extends ConsumerStatefulWidget {
  final String orgId;
  const UnifiedAlertsDropdown({super.key, required this.orgId});

  @override
  ConsumerState<UnifiedAlertsDropdown> createState() =>
      _UnifiedAlertsDropdownState();
}

class _UnifiedAlertsDropdownState extends ConsumerState<UnifiedAlertsDropdown> {
  final List _items = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final svc = ref.read(alertsFeedServiceProvider);
    _sub = svc.streamOrgAlerts(widget.orgId).listen((a) {
      setState(() {
        _items.insert(0, a);
        if (_items.length > 20) _items.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Notifications',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications),
          if (_items.isNotEmpty)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_items.length}',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      itemBuilder: (ctx) {
        if (_items.isEmpty) {
          return [
            const PopupMenuItem(
              enabled: false,
              child: Text('No notifications'),
            ),
          ];
        }
        return _items.take(8).toList().asMap().entries.map((e) {
          final a = e.value;
          return PopupMenuItem<int>(
            value: e.key,
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      a.kind == 'delay'
                          ? Icons.schedule
                          : a.kind == 'weigh'
                          ? Icons.local_police
                          : Icons.shield_outlined,
                    ),
                    title: Text(
                      a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      a.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Acknowledge',
                  icon: const Icon(Icons.check),
                  onPressed: () async {
                    try {
                      // Best-effort: If mapped to alerts_events id, we could call AlertsService. For mock, locally dismiss.
                      // If a backing service exists, acknowledge on backend too.
                      setState(() {
                        _items.removeAt(e.key);
                      });
                      Navigator.pop(ctx);
                    } catch (_) {}
                  },
                ),
              ],
            ),
          );
        }).toList();
      },
      onSelected: (_) {},
    );
  }
}
