import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssistantModeTile extends StatefulWidget {
  const AssistantModeTile({super.key});
  @override
  State<AssistantModeTile> createState() => _AssistantModeTileState();
}

class _AssistantModeTileState extends State<AssistantModeTile> {
  bool mode = false; bool busy = false;
  Future<void> _load() async {
    final c = Supabase.instance.client;
    final orgId = c.auth.currentUser?.userMetadata?['org_id'];
    if (orgId == null) return;
    final row = await c.from('assistant_settings').select('assistant_mode').eq('org_id', orgId).maybeSingle();
    if (!mounted) return;
    setState(() => mode = (row?['assistant_mode'] ?? false) == true);
  }
  Future<void> _save(bool v) async {
    setState(() => busy = true);
    final c = Supabase.instance.client;
    final orgId = c.auth.currentUser?.userMetadata?['org_id'];
    if (orgId != null) {
      await c.from('assistant_settings').upsert({'org_id': orgId, 'assistant_mode': v});
    }
    if (!mounted) return;
    setState(() { mode = v; busy = false; });
  }
  @override
  void initState() { super.initState(); _load(); }
  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: const Text('Assistant mode'),
    subtitle: const Text('Propose next 2 legs; approve to send requests'),
    value: mode, onChanged: busy ? null : _save
  );
}
