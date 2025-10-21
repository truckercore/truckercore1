import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LegalOnboardingScreen extends StatefulWidget {
  const LegalOnboardingScreen({super.key});
  @override
  State<LegalOnboardingScreen> createState() => _LegalOnboardingScreenState();
}

class _LegalOnboardingScreenState extends State<LegalOnboardingScreen> {
  final _sb = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _dot = TextEditingController();
  final _mc = TextEditingController();
  bool isOwnerOp = false;
  bool submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => submitting = true);
    try {
      final uid = _sb.auth.currentUser!.id;
      await _sb.from('credentials').upsert({
        'user_id': uid,
        'dot': _dot.text.trim(),
        'mc': _mc.text.trim().isEmpty ? null : _mc.text.trim(),
        'role_hint': isOwnerOp ? 'owner_operator' : 'driver',
      });
      await _sb.functions.invoke('verify-credentials', body: { 'user_id': uid });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted. We’ll notify upon verification.')));
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify to Continue')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            SwitchListTile(
              value: isOwnerOp,
              onChanged: (v) => setState(() => isOwnerOp = v),
              title: const Text('I am an Owner-Operator'),
            ),
            TextFormField(
              controller: _dot,
              decoration: const InputDecoration(labelText: 'DOT Number (required)'),
              validator: (v) => (v == null || v.isEmpty) ? 'DOT required' : null,
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _mc,
              decoration: const InputDecoration(labelText: 'MC Number (optional for Owner-Op)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: submitting ? null : _submit,
              child: Text(submitting ? 'Submitting…' : 'Submit & Verify'),
            ),
            const SizedBox(height: 8),
            const Text('We verify with FMCSA and mark your account Verified.'),
          ]),
        ),
      ),
    );
  }
}
