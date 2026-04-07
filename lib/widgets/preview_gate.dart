// lib/widgets/preview_gate.dart
// PreviewGate and UpsellCard widgets to gate premium-only areas with a teaser and CTA.

import 'package:flutter/material.dart';
import '../services/premium_service.dart';

class PreviewGate extends StatefulWidget {
  final Widget premiumChild;
  final Widget previewChild; // small teaser (blurred/limited)
  final String featureName; // e.g., 'AI Suggestions'
  final int trialDays;
  const PreviewGate({
    super.key,
    required this.premiumChild,
    required this.previewChild,
    required this.featureName,
    this.trialDays = 7,
  });

  @override
  State<PreviewGate> createState() => _PreviewGateState();
}

class _PreviewGateState extends State<PreviewGate> {
  bool _loading = true;
  bool _premium = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    try {
      _premium = await isPremium();
      _err = null;
    } catch (e) {
      _err = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startTrial() async {
    try {
      await startTrialAndRefresh(days: widget.trialDays);
      await _check();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trial started — enjoy ${widget.featureName}!')),
      );
    } catch (e) {
      final msg = '$e';
      if (msg.contains('TRIAL_ALREADY_USED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trial already used — consider upgrading.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start trial: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null) {
      return Column(
        children: [
          Text('Error: $_err'),
          TextButton(onPressed: _check, child: const Text('Retry')),
        ],
      );
    }
    if (_premium) return widget.premiumChild;

    return UpsellCard(
      featureName: widget.featureName,
      preview: widget.previewChild,
      onStartTrial: _startTrial,
      trialDays: widget.trialDays,
    );
  }
}

class UpsellCard extends StatelessWidget {
  final String featureName;
  final Widget preview;
  final VoidCallback onStartTrial;
  final int trialDays;
  const UpsellCard({
    super.key,
    required this.featureName,
    required this.preview,
    required this.onStartTrial,
    required this.trialDays,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(featureName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Opacity(opacity: 0.65, child: preview),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onStartTrial,
                icon: const Icon(Icons.flash_on),
                label: Text('Start $trialDays\u2011day trial'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Upgrade flow coming soon')));
                },
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Upgrade'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Preview shown — unlock the full experience with a free trial or upgrade.'),
        ]),
      ),
    );
  }
}
