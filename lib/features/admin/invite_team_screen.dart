// Team Invites admin screen: create invites in org_invites table
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteTeamScreen extends StatefulWidget {
  const InviteTeamScreen({super.key});
  @override
  State<InviteTeamScreen> createState() => _InviteTeamScreenState();
}

class _InviteTeamScreenState extends State<InviteTeamScreen> {
  final _email = TextEditingController();
  String _role = 'viewer';
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final c = Supabase.instance.client;
      final orgId = c.auth.currentUser?.userMetadata?['org_id'];
      if (orgId == null) return;
      // Insert into org_invites (assumes policies allow admin)
      final res = await c.from('org_invites').insert({
        'org_id': orgId,
        'email': _email.text.trim(),
        'role': _role,
        'token': DateTime.now().millisecondsSinceEpoch.toString(), // replace with secure token
        'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String()
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error == null ? 'Invite created' : 'Failed: ${res.error!.message}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Team')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _role,
            items: const [
              DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
              DropdownMenuItem(value: 'driver', child: Text('Driver')),
              DropdownMenuItem(value: 'dispatcher', child: Text('Dispatcher')),
              DropdownMenuItem(value: 'broker', child: Text('Broker')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'viewer'),
            decoration: const InputDecoration(labelText: 'Role'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _busy ? null : _send, child: const Text('Send Invite')),
        ]),
      ),
    );
  }
}
