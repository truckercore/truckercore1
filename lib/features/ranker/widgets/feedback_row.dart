// lib/features/ranker/widgets/feedback_row.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/telemetry/perf_tracing.dart';
import '../../../core/flags/rollout_flags.dart';
import '../../../core/supabase/supabase_factory.dart';

class RankerFeedbackRow extends ConsumerWidget {
  const RankerFeedbackRow({super.key, required this.loadId});
  final String loadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(rolloutFlagsProvider).rankerV1Enabled;
    if (!enabled) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.thumb_up_alt_outlined),
          onPressed: () async {
            await _sendFeedback(ref, up: true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your feedback')));
            }
          },
          tooltip: 'Thumbs up',
        ),
        IconButton(
          icon: const Icon(Icons.thumb_down_alt_outlined),
          onPressed: () async {
            final reason = await _pickReason(context);
            if (reason == null) return;
            await _sendFeedback(ref, up: false, reason: reason);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Well use this to improve')));
            }
          },
          tooltip: 'Thumbs down',
        ),
      ],
    );
  }

  Future<String?> _pickReason(BuildContext context) async {
    final reasons = ['Rate', 'Too far', 'Timing', 'Equipment', 'Other'];
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Why not?')),
            for (final r in reasons)
              ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(ctx, r.toLowerCase()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendFeedback(WidgetRef ref, {required bool up, String? reason}) async {
    final factory = ref.read(supabaseFactoryProvider);
    final client = factory.maybeClient;
    if (client == null) return; // no-op in mock/offline mode
    try {
      await client.functions.invokeWithTrace(
        'ranker_feedback_v1',
        action: 'ranker.feedback',
        body: jsonEncode({'load_id': loadId, 'up': up, 'reason': reason}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (_) {}
  }
}
