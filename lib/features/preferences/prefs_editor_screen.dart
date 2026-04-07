// lib/features/preferences/prefs_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truckercore1/l10n/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import 'state/prefs_providers.dart';

class PrefsEditorScreen extends ConsumerStatefulWidget {
  const PrefsEditorScreen({super.key});

  @override
  ConsumerState<PrefsEditorScreen> createState() => _PrefsEditorScreenState();
}

class _PrefsEditorScreenState extends ConsumerState<PrefsEditorScreen> {
  final _form = GlobalKey<FormState>();
  String? _equipment;
  double? _minCpm;
  String? _homeLat;
  String? _homeLng;
  String? _homeRadius;
  final _preferredLanesCtrl = TextEditingController();
  final _dislikedBrokersCtrl = TextEditingController();
  DateTime? _pickupStart;
  DateTime? _pickupEnd;

  @override
  void dispose() {
    _preferredLanesCtrl.dispose();
    _dislikedBrokersCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(userPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (prefs) {
          _equipment ??= prefs.defaultEquipment;
          _minCpm ??= prefs.minCpm;
          _homeLat ??= prefs.homeBaseLat?.toString();
          _homeLng ??= prefs.homeBaseLng?.toString();
          _homeRadius ??= prefs.homeRadiusMi?.toString();
          if (_preferredLanesCtrl.text.isEmpty && prefs.preferredLanes.isNotEmpty) {
            _preferredLanesCtrl.text = prefs.preferredLanes.join(',');
          }
          if (_dislikedBrokersCtrl.text.isEmpty && prefs.dislikedBrokers.isNotEmpty) {
            _dislikedBrokersCtrl.text = prefs.dislikedBrokers.join(',');
          }
          _pickupStart ??= prefs.pickupWindowStartIso != null ? DateTime.tryParse(prefs.pickupWindowStartIso!) : null;
          _pickupEnd ??= prefs.pickupWindowEndIso != null ? DateTime.tryParse(prefs.pickupWindowEndIso!) : null;

          return SafeArea(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Default equipment (e.g., Dry Van)')
                        .applyDefaults(Theme.of(context).inputDecorationTheme),
                    initialValue: _equipment,
                    onChanged: (v) => _equipment = v.trim().isEmpty ? null : v.trim(),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Min ' r'$' '/mi').applyDefaults(Theme.of(context).inputDecorationTheme),
                    keyboardType: TextInputType.number,
                    initialValue: _minCpm?.toString(),
                    onChanged: (v) => _minCpm = double.tryParse(v),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Home base lat'),
                          keyboardType: TextInputType.number,
                          initialValue: _homeLat,
                          onChanged: (v) => _homeLat = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Home base lng'),
                          keyboardType: TextInputType.number,
                          initialValue: _homeLng,
                          onChanged: (v) => _homeLng = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Radius mi'),
                          keyboardType: TextInputType.number,
                          initialValue: _homeRadius,
                          onChanged: (v) => _homeRadius = v,
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _preferredLanesCtrl,
                    decoration: const InputDecoration(labelText: 'Preferred lanes (comma separated)'),
                  ),
                  TextField(
                    controller: _dislikedBrokersCtrl,
                    decoration: const InputDecoration(labelText: 'Disliked brokers (comma separated)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: now.subtract(const Duration(days: 1)),
                              lastDate: now.add(const Duration(days: 365)),
                              initialDate: _pickupStart ?? now,
                            );
                            if (picked != null) setState(() => _pickupStart = picked);
                          },
                          child: Text(_pickupStart == null ? 'Pickup start' : _pickupStart!.toLocal().toString().split(' ').first),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: now.subtract(const Duration(days: 1)),
                              lastDate: now.add(const Duration(days: 365)),
                              initialDate: _pickupEnd ?? _pickupStart ?? now,
                            );
                            if (picked != null) setState(() => _pickupEnd = picked);
                          },
                          child: Text(_pickupEnd == null ? 'Pickup end' : _pickupEnd!.toLocal().toString().split(' ').first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    onPressed: () async {
                      final p = UserPrefs(
                        defaultEquipment: _equipment,
                        minCpm: _minCpm,
                        homeBaseLat: double.tryParse(_homeLat ?? ''),
                        homeBaseLng: double.tryParse(_homeLng ?? ''),
                        homeRadiusMi: double.tryParse(_homeRadius ?? ''),
                        preferredLanes: _preferredLanesCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                        dislikedBrokers: _dislikedBrokersCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                        pickupWindowStartIso: _pickupStart?.toUtc().toIso8601String(),
                        pickupWindowEndIso: _pickupEnd?.toUtc().toIso8601String(),
                      );
                      await ref.read(userPrefsProvider.notifier).save(p);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences saved')));
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(Strings.current.privacyWhatWeTrackTitle),
                    subtitle: Text(Strings.current.privacyWhatWeTrackSubtitle),
                    onTap: () => _openUrl('https://www.example.com/privacy'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(Strings.current.privacyPolicyTitle),
                    onTap: () => _openUrl('https://www.example.com/privacy'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: Text(Strings.current.termsTitle),
                    onTap: () => _openUrl('https://www.example.com/terms'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
