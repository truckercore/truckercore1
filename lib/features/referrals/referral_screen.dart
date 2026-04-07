// Referral screen: generate/share code and claim code via RPC
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _randCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
}

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final c = Supabase.instance.client;
  String? _code;
  bool _busy = false;
  final _claimCtrl = TextEditingController();

  Future<void> _issue() async {
    setState(() => _busy = true);
    try {
      final uid = c.auth.currentUser?.id;
      final orgId = c.auth.currentUser?.userMetadata?['org_id'];
      if (uid == null || orgId == null) return;
      final code = _randCode();
      final res = await c.from('referrals').insert({
        'org_id': orgId,
        'referrer_user_id': uid,
        'code': code,
        'incentive_cents': 2500
      });
      if (res.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${res.error!.message}')),
          );
        }
      } else {
        if (mounted) setState(() => _code = code);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final uid = c.auth.currentUser?.id;
      final code = _claimCtrl.text.trim().toUpperCase();
      if (uid == null || code.isEmpty) return;
      final res = await c.rpc('fn_referral_claim', params: {'p_code': code, 'p_user_id': uid});
      if (!mounted) return;
      if (res.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral claimed')));
        _claimCtrl.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${res.error!.message}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _claimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Referrals')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          ListTile(
            title: const Text('Your referral code'),
            subtitle: Text(_code ?? 'None issued'),
            trailing: ElevatedButton(
              onPressed: _busy ? null : _issue,
              child: const Text('Generate'),
            ),
          ),
          const Divider(),
          TextField(controller: _claimCtrl, decoration: const InputDecoration(labelText: 'Enter referral code')),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _busy ? null : _claim, child: const Text('Claim')),
        ]),
      ),
    );
  }
}
