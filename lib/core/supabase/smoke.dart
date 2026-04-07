import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSmoke extends StatefulWidget {
  const SupabaseSmoke({super.key});
  @override
  State<SupabaseSmoke> createState() => _SupabaseSmokeState();
}

class _SupabaseSmokeState extends State<SupabaseSmoke> {
  String status = 'Running…';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final client = Supabase.instance.client;
      final health = await client
          .from('health_ping_view')
          .select('now')
          .limit(1);
      final page = await client
          .from('escalation_logs')
          .select('title, created_at')
          .order('created_at', ascending: false)
          .limit(1);
      setState(() => status =
          'OK • health=${(health as List).isNotEmpty ? (health.first as Map)['now'] : 'n/a'} • latest=${(page as List).isEmpty ? 'none' : (page.first as Map)['title']}');
    } catch (e) {
      setState(() => status = 'ERR • $e');
    }
  }

  @override
  Widget build(BuildContext context) =>
      Text(status, style: Theme.of(context).textTheme.bodySmall);
}
