import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BrandingSettings extends StatefulWidget {
  const BrandingSettings({super.key});
  @override
  State<BrandingSettings> createState() => _BrandingSettingsState();
}

class _BrandingSettingsState extends State<BrandingSettings> {
  final logoCtrl = TextEditingController();
  final primaryCtrl = TextEditingController(text: '#0D47A1');
  final accentCtrl = TextEditingController(text: '#FFC107');
  final domainCtrl = TextEditingController();
  bool busy = false;

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final orgId = c.auth.currentUser?.userMetadata?['org_id'];
    if (orgId == null) return;
    final row = await c.from('org_branding').select('logo_url,primary_color,accent_color,domain').eq('org_id', orgId).maybeSingle();
    if (!mounted) return;
    setState(() {
      if (row != null) {
        logoCtrl.text = (row['logo_url'] ?? '') as String;
        primaryCtrl.text = (row['primary_color'] ?? primaryCtrl.text) as String;
        accentCtrl.text = (row['accent_color'] ?? accentCtrl.text) as String;
        domainCtrl.text = (row['domain'] ?? '') as String;
      }
    });
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final c = Supabase.instance.client;
    final orgId = c.auth.currentUser?.userMetadata?['org_id'];
    if (orgId != null) {
      await c.from('org_branding').upsert({
        'org_id': orgId,
        'logo_url': logoCtrl.text.trim(),
        'primary_color': primaryCtrl.text.trim(),
        'accent_color': accentCtrl.text.trim(),
        'domain': domainCtrl.text.trim(),
      });
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
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const ListTile(title: Text('Branding')),
            TextField(controller: logoCtrl, decoration: const InputDecoration(labelText: 'Logo URL')),
            TextField(controller: primaryCtrl, decoration: const InputDecoration(labelText: 'Primary color (hex)')),
            TextField(controller: accentCtrl, decoration: const InputDecoration(labelText: 'Accent color (hex)')),
            TextField(controller: domainCtrl, decoration: const InputDecoration(labelText: 'Custom domain (optional)')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: busy ? null : _save, child: const Text('Save')),
          ]),
        ),
      );
}
