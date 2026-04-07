import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteWizard extends StatefulWidget {
  final String orgId;
  const InviteWizard({super.key, required this.orgId});

  @override
  State<InviteWizard> createState() => _InviteWizardState();
}

class _InviteWizardState extends State<InviteWizard> {
  String? _domain;
  List<Map<String, String>> _preview = [];
  bool _busy = false;
  String? _result;

  Future<void> _pickCsv() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (res == null || res.files.isEmpty) return;
    final content = utf8.decode(res.files.first.bytes!);
    // Parse very simple CSV: email, role
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty);
    final rows = <Map<String,String>>[];
    for (final l in lines) {
      final parts = l.split(',').map((s) => s.trim()).toList();
      if (parts.isEmpty) continue;
      final email = parts[0];
      final role = parts.length > 1 ? parts[1] : 'driver';
      rows.add({'email': email, 'role': role});
    }
    setState(() => _preview = rows);
  }

  Future<void> _sendInvites() async {
    if (_preview.isEmpty) return;
    setState(() { _busy = true; _result = null; });
    try {
      final payload = {
        'org_id': widget.orgId,
        'invites': _preview.map((r) => {'email': r['email'], 'role': r['role']}).toList()
      };
      final fn = await Supabase.instance.client.functions.invoke('createInvites', body: payload);
      if (fn.data?['ok'] == true) {
        setState(() => _result = 'Invites created: ${fn.data['created']}');
      } else {
        setState(() => _result = 'Failed: ${fn.data?['error'] ?? 'unknown'}');
      }
    } catch (e) {
      setState(() => _result = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _saveDomain() async {
    if ((_domain ?? '').isEmpty) return;
    final c = Supabase.instance.client;
    await c.from('orgs').update({'email_domain': _domain}).eq('id', widget.orgId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Domain saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Team')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('A) Bulk CSV Invites', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                ElevatedButton.icon(onPressed: _pickCsv, icon: const Icon(Icons.upload_file), label: const Text('Upload CSV')),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: _busy ? null : _sendInvites, icon: _busy ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.send), label: const Text('Send Invites')),
              ],
            ),
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Preview: ${_preview.length} rows'),
            ],
            if (_result != null) Padding(padding: const EdgeInsets.only(top:8), child: Text(_result!)),
            const Divider(height: 32),
            const Text('B) Domain Auto-Join', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: TextField(decoration: const InputDecoration(labelText: 'email domain (e.g., myfleet.com)'), onChanged: (v) => _domain = v.trim())),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _saveDomain, child: const Text('Save')),
              ],
            ),
            const Divider(height: 32),
            const Text('C) QR Codes for Drivers (no email)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Generate one-time codes server-side (roadmap): show printable sheet with codes/QR and a short URL like app://accept-invite?token=...'),
          ],
        ),
      ),
    );
  }
}
