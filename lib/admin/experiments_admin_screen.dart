import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ExperimentsAdminScreen extends StatefulWidget {
  const ExperimentsAdminScreen({super.key});
  @override
  State<ExperimentsAdminScreen> createState() => _ExperimentsAdminState();
}

class _ExperimentsAdminState extends State<ExperimentsAdminScreen> {
  List rows = [];
  String? error;
  final adminToken = const String.fromEnvironment('AB_ADMIN_TOKEN');
  final fnBase = const String.fromEnvironment('FN_BASE');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await http.get(
        Uri.parse('$fnBase/ab_admin?action=list'),
        headers: {'X-Admin-Token': adminToken},
      );
      final j = jsonDecode(r.body);
      if (j['status'] != 'ok') throw Exception(j['message']);
      setState(() => rows = j['data']['items']);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _action(String key, String action) async {
    await http.post(
      Uri.parse('$fnBase/ab_admin?action=$action'),
      headers: {'X-Admin-Token': adminToken, 'Content-Type': 'application/json'},
      body: jsonEncode({'key': key}),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Experiments Admin')),
      body: error != null
          ? Center(child: Text('Error: $error'))
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final r = rows[i] as Map<String, dynamic>;
                return ListTile(
                  title: Text(r['key'] as String),
                  subtitle: Text('${r['feature_key']} • ${r['env']} • ${r['status']}'),
                  trailing: Wrap(spacing: 8, children: [
                    Text('${(((r['e2e_conv_30d'] ?? 0) as num) * 100).toStringAsFixed(2)}% E2E'),
                    TextButton(onPressed: () => _action(r['key'] as String, 'pause'), child: const Text('Pause')),
                    TextButton(onPressed: () => _action(r['key'] as String, 'archive'), child: const Text('Archive')),
                  ]),
                );
              }),
    );
  }
}
