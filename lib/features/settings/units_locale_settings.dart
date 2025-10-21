import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnitsLocaleSettings extends StatefulWidget {
  const UnitsLocaleSettings({super.key});
  @override
  State<UnitsLocaleSettings> createState() => _UnitsLocaleSettingsState();
}

class _UnitsLocaleSettingsState extends State<UnitsLocaleSettings> {
  bool metric = false;
  bool clock24 = false;
  String locale = 'en';
  bool busy = false;

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final uid = c.auth.currentUser?.id;
    if (uid == null) return;
    final row = await c
        .from('profiles')
        .select('units_metric,clock_24h,locale')
        .eq('id', uid)
        .maybeSingle();
    if (!mounted) return;
    setState(() {
      metric = (row?['units_metric'] ?? false) == true;
      clock24 = (row?['clock_24h'] ?? false) == true;
      locale = (row?['locale'] ?? 'en') as String;
    });
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final c = Supabase.instance.client;
    final uid = c.auth.currentUser?.id;
    if (uid != null) {
      await c
          .from('profiles')
          .update({'units_metric': metric, 'clock_24h': clock24, 'locale': locale})
          .eq('id', uid);
    }
    if (!mounted) return;
    setState(() => busy = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const ListTile(title: Text('Units & Locale')),
          SwitchListTile(
              title: const Text('Metric units'),
              subtitle: const Text('km, kg'),
              value: metric,
              onChanged: busy ? null : (v) => setState(() => metric = v)),
          SwitchListTile(
              title: const Text('24‑hour clock'),
              value: clock24,
              onChanged: busy ? null : (v) => setState(() => clock24 = v)),
          DropdownButtonFormField<String>(
            initialValue: locale,
            decoration: const InputDecoration(labelText: 'Language'),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'es', child: Text('Español')),
              DropdownMenuItem(value: 'fr', child: Text('Français')),
            ],
            onChanged: busy ? null : (v) => setState(() => locale = v ?? 'en'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: busy ? null : _save, child: const Text('Save'))
        ]),
      ),
    );
  }
}
