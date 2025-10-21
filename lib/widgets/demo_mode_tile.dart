// Demo Mode toggle for Org settings
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DemoModeTile extends StatefulWidget {
  const DemoModeTile({super.key});
  @override
  State<DemoModeTile> createState() => _DemoModeTileState();
}

class _DemoModeTileState extends State<DemoModeTile> {
  bool _demo = false;
  bool _busy = false;

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final orgId = c.auth.currentUser?.userMetadata?['org_id'];
    if (orgId == null) return;
    final res = await c.from('orgs').select('demo_mode').eq('id', orgId).maybeSingle();
    if (mounted) setState(() => _demo = (res?['demo_mode'] ?? false) == true);
  }

  Future<void> _save(bool v) async {
    setState(() => _busy = true);
    final c = Supabase.instance.client;
    final orgId = c.auth.currentUser?.userMetadata?['org_id'];
    if (orgId != null) {
      await c.from('orgs').update({'demo_mode': v}).eq('id', orgId);
    }
    if (mounted) {
      setState(() {
      _demo = v;
      _busy = false;
    });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Demo mode'),
      subtitle: const Text('Loads sample data for sales/training'),
      value: _demo,
      onChanged: _busy ? null : _save,
    );
  }
}
