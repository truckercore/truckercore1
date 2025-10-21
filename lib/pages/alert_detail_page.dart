import 'package:flutter/material.dart';
import '../core/supabase/client.dart';

class AlertDetailPage extends StatefulWidget {
  final String alertId;
  const AlertDetailPage({super.key, required this.alertId});

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  Map<String, dynamic>? _alert;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await TC.getById(from: 'alerts', idCol: 'id', id: widget.alertId);
    setState(() {
      _alert = row;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_alert == null) {
      return const Scaffold(body: Center(child: Text('Alert not found')));
    }
    return Scaffold(
      appBar: AppBar(title: Text(_alert!['title'] ?? 'Alert')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_alert!['description'] ?? 'No description'),
          const SizedBox(height: 12),
          Text('Severity: ${_alert!['severity'] ?? 'n/a'}'),
          Text('Status: ${_alert!['status'] ?? 'n/a'}'),
        ],
      ),
    );
  }
}
