import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AcceptInviteScreen extends StatefulWidget {
  final String token;
  const AcceptInviteScreen({super.key, required this.token});

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _status;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'acceptInvite',
        body: {
          'token': widget.token,
          'email': _email.text.trim(),
          'password': _password.text.trim().isEmpty ? null : _password.text.trim(),
        },
      );
      if (!mounted) return;
      if (res.data?['ok'] == true) {
        setState(() => _status = 'Success. You can now log in.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite accepted')));
        Navigator.of(context).pushReplacementNamed('/auth/login');
      } else {
        setState(() => _status = res.data?['error'] ?? 'Unable to accept');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accept Invite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email (optional if already on invite)')),
            const SizedBox(height: 8),
            TextField(controller: _password, decoration: const InputDecoration(labelText: 'Set Password (optional)'), obscureText: true),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _accept,
              icon: _busy ? const SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.check),
              label: const Text('Accept Invite'),
            ),
            if (_status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status!)),
          ],
        ),
      ),
    );
  }
}
