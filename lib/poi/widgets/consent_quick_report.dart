// lib/poi/widgets/consent_quick_report.dart
import 'package:flutter/material.dart';

/// Consent + Quick Report UI skeleton for Phase 1.
///
/// Provides a simple consent toggle set and quick-report chips for Parking and Weigh Station.
/// Intended to be embedded in a dev/debug screen to accelerate the UI loop.
class ConsentAndQuickReport extends StatefulWidget {
  final Future<void> Function(bool enabledAlways, bool enabledNav) onConsentChanged;
  final Future<void> Function(String kind, String status) onReport;
  final DateTime? lastContributionAt;
  final VoidCallback? onOptOut;

  const ConsentAndQuickReport({
    super.key,
    required this.onConsentChanged,
    required this.onReport,
    this.lastContributionAt,
    this.onOptOut,
  });

  @override
  State<ConsentAndQuickReport> createState() => _ConsentAndQuickReportState();
}

class _ConsentAndQuickReportState extends State<ConsentAndQuickReport> {
  bool always = false;
  bool whileNavigating = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Telemetry Consent', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Always'),
              value: always,
              onChanged: (v) async {
                setState(() => always = v);
                await widget.onConsentChanged(always, whileNavigating);
              },
            ),
            SwitchListTile(
              title: const Text('While navigating'),
              value: whileNavigating,
              onChanged: (v) async {
                setState(() => whileNavigating = v);
                await widget.onConsentChanged(always, whileNavigating);
              },
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quick Report', style: TextStyle(fontWeight: FontWeight.bold)),
                if (widget.lastContributionAt != null)
                  Chip(
                    label: Text('Last: ${_fmtAgo(widget.lastContributionAt!)}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Parking: Open', () => _handleReport('parking', 'open')),
                _chip('Parking: Some', () => _handleReport('parking', 'some')),
                _chip('Parking: Full', () => _handleReport('parking', 'full')),
                _chip('Weigh: Open', () => _handleReport('weigh', 'open')),
                _chip('Weigh: Closed', () => _handleReport('weigh', 'closed')),
                _chip('Weigh: Bypass', () => _handleReport('weigh', 'bypass')),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onOptOut,
                child: const Text('Opt out of telemetry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 5) return 'just now';
    if (d.inMinutes < 1) return '${d.inSeconds}s ago';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Widget _chip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }

  Future<void> _handleReport(String kind, String status) async {
    try {
      await widget.onReport(kind, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reported $kind: $status')),
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      String hint = 'Please try again later';
      if (msg.contains('429') || msg.contains('rate') || msg.contains('limit')) {
        hint = 'Try again in a few minutes';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report. $hint')),
      );
    }
  }
}
