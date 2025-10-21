// Onboarding Checklist widget
// Reads/writes onboarding_checklist table in Supabase per user/org

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum OnbStep { connectData, setPrefs, saveWatch, sendRequest }

const stepToKey = {
  OnbStep.connectData: 'connect_data',
  OnbStep.setPrefs: 'set_prefs',
  OnbStep.saveWatch: 'save_watch',
  OnbStep.sendRequest: 'send_request',
};

class OnboardingChecklist extends StatefulWidget {
  const OnboardingChecklist({super.key});
  @override
  State<OnboardingChecklist> createState() => _OnboardingChecklistState();
}

class _OnboardingChecklistState extends State<OnboardingChecklist> {
  final c = Supabase.instance.client;
  final Map<String, String> _statuses = {}; // step_key -> status
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final uid = c.auth.currentUser?.id;
      final orgId = c.auth.currentUser?.userMetadata?['org_id'];
      if (uid == null || orgId == null) return;
      final res = await c
          .from('onboarding_checklist')
          .select('step_key,status')
          .eq('org_id', orgId)
          .eq('user_id', uid);
      final map = <String, String>{};
      for (final row in (res as List<dynamic>? ?? [])) {
        map[row['step_key'] as String] = row['status'] as String;
      }
      if (mounted) setState(() => _statuses.addAll(map));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mark(String stepKey, String status) async {
    final uid = c.auth.currentUser?.id;
    final orgId = c.auth.currentUser?.userMetadata?['org_id'];
    if (uid == null || orgId == null) return;
    await c.from('onboarding_checklist').upsert({
      'org_id': orgId,
      'user_id': uid,
      'step_key': stepKey,
      'status': status,
      'updated_at': DateTime.now().toIso8601String()
    });
    if (mounted) setState(() => _statuses[stepKey] = status);
  }

  Widget _row(String label, OnbStep step, VoidCallback go) {
    final key = stepToKey[step]!;
    final done = _statuses[key] == 'done';
    return ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Colors.green : null,
      ),
      title: Text(label),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(onPressed: () => _mark(key, 'done'), child: const Text('Mark done')),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: go, child: const Text('Go')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: [
        const ListTile(title: Text('Getting started')),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        _row('Connect data', OnbStep.connectData, () {
          // TODO: navigate to Integrations
        }),
        _row('Set preferences', OnbStep.setPrefs, () {
          // TODO: navigate to Preferences
        }),
        _row('Save first watch', OnbStep.saveWatch, () {
          // TODO: open Watch lane screen
        }),
        _row('Send first request', OnbStep.sendRequest, () {
          // TODO: open Suggestion/Request flow
        }),
        const SizedBox(height: 8),
      ]),
    );
  }
}
