// lib/features/carriers/carrier_scorecard.dart
// Carrier composite score fetching + reusable UI widgets.
// Usage examples are included at the bottom of this file in comments.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Single access to Supabase client
final _supabase = Supabase.instance.client;

// Fetch composite score (jsonb) via RPC
Future<Map<String, dynamic>> _fetchCompositeScore(String carrierId) async {
  final data = await _supabase.rpc('carrier_composite_score', params: {
    'cid': carrierId,
  });
  if (data == null) throw Exception('No score data');
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  // Some PostgREST configs may wrap in a list
  if (data is List && data.isNotEmpty && data.first is Map) {
    return Map<String, dynamic>.from(data.first as Map);
  }
  throw Exception('Unexpected score shape');
}

// Riverpod provider (family) to fetch by carrierId
final carrierScoreProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, carrierId) async {
  return _fetchCompositeScore(carrierId);
});

// Tier → color/icon map
Color tierColor(BuildContext ctx, String tier) {
  final cs = Theme.of(ctx).colorScheme;
  switch (tier.toLowerCase()) {
    case 'gold':
      return Colors.amber.shade600;
    case 'silver':
      return Colors.blueGrey.shade300;
    case 'bronze':
      return Colors.brown.shade400;
    case 'unrated':
      return cs.surfaceContainerHighest;
    default:
      return cs.secondary;
  }
}

IconData tierIcon(String tier) {
  switch (tier.toLowerCase()) {
    case 'gold':
      return Icons.verified;
    case 'silver':
      return Icons.verified_user;
    case 'bronze':
      return Icons.verified_outlined;
    default:
      return Icons.help_outline;
  }
}

// Optional: apply contracting guardrails (simple policy)
Map<String, dynamic> applyGuardrails(Map<String, dynamic> score, {int loadsCompleted = 0}) {
  final tier = (score['tier'] ?? 'UNRATED').toString();
  final reasons = List<String>.from(score['reasons'] ?? const []);
  if (tier.toLowerCase() == 'bronze') {
    return {
      'allowed': true,
      'caps': {
        'maxLoadValue': 5000,
        'maxDistance': 500,
        'probationLoads': 5,
      },
      'extraChecks': ['photo_proof', 'geo_ping'],
      'reasons': reasons,
    };
  } else if (tier.toLowerCase() == 'silver') {
    return {
      'allowed': true,
      'caps': {
        'maxLoadValue': 20000,
        'maxDistance': 1500,
      },
      'extraChecks': ['doc_gate'],
      'reasons': reasons,
    };
  } else if (tier.toLowerCase() == 'gold') {
    return {
      'allowed': true,
      'priority': true,
      'reasons': reasons,
    };
  } else {
    return {
      'allowed': false,
      'reasons': ['Unrated carrier — needs docs and signals'],
    };
  }
}

// Dart: Tier badge
class CarrierTierBadge extends StatelessWidget {
  final String tier;
  const CarrierTierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = tierColor(context, tier);
    return Chip(
      avatar: Icon(tierIcon(tier), color: Colors.white, size: 18),
      label: Text(tier, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// Dart: Score ring (compact gauge)
class ScoreRing extends StatelessWidget {
  final num score; // 0..100
  final double size;
  const ScoreRing({super.key, required this.score, this.size = 60});

  @override
  Widget build(BuildContext context) {
    final s = score.clamp(0, 100).toDouble();
    final pct = s / 100.0;
    final cs = Theme.of(context).colorScheme;
    final ringColor = s >= 80
        ? Colors.green
        : s >= 65
            ? Colors.orange
            : Colors.red;

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct,
            color: ringColor,
            backgroundColor: cs.surfaceContainerHighest,
            strokeWidth: 6,
          ),
          Text(s.toStringAsFixed(0), style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

// Dart: Reasons and fix‑it guidance chips
class ReasonChips extends StatefulWidget {
  final List<String> reasons;
  final int maxVisible; // how many to show before "+N more"
  const ReasonChips({super.key, required this.reasons, this.maxVisible = 3});

  @override
  State<ReasonChips> createState() => _ReasonChipsState();
}

class _ReasonChipsState extends State<ReasonChips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final reasons = List<String>.from(widget.reasons);
    if (reasons.isEmpty) return const SizedBox.shrink();

    final all = reasons;
    final visible = _expanded ? all : all.take(widget.maxVisible).toList();
    final hiddenCount = all.length - visible.length;

    final List<Widget> chips = visible
        .map((r) => Chip(
              label: Text(r),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ))
        .toList();

    if (!_expanded && hiddenCount > 0) {
      chips.add(ActionChip(
        label: Text('+$hiddenCount more'),
        onPressed: () => setState(() => _expanded = true),
      ));
    } else if (_expanded && all.length > widget.maxVisible) {
      chips.add(ActionChip(
        label: const Text('Show less'),
        onPressed: () => setState(() => _expanded = false),
      ));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }
}

class FixItList extends StatelessWidget {
  final List<String> items;
  final void Function(String key)? onAction; // optional callback
  const FixItList({super.key, required this.items, this.onAction});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fixit guidance', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ...items.map((t) => ListTile(
              dense: true,
              leading: const Icon(Icons.build_circle_outlined),
              title: Text(t),
              trailing: onAction == null
                  ? null
                  : TextButton(
                      onPressed: () => onAction!(t),
                      child: const Text('Resolve'),
                    ),
            )),
      ],
    );
  }
}

// Dart: Components table (explainable subscores)
class ComponentsTable extends StatelessWidget {
  final Map<String, dynamic> components; // { hos_sub: 90, safety_sub: 80, ... }
  const ComponentsTable({super.key, required this.components});

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) return const SizedBox.shrink();
    final entries = components.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Components', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ...entries.map((e) {
          final label = e.key.replaceAll('_', ' ');
          final val = (e.value is num)
              ? (e.value as num).toStringAsFixed(0)
              : '${e.value}';
          return Row(
            children: [
              Expanded(child: Text(label)),
              Text(val, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          );
        }),
      ],
    );
  }
}

// Dart: Guardrails banner (actionable)
class GuardrailsBanner extends StatelessWidget {
  final Map<String, dynamic> score;
  const GuardrailsBanner({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final policy = applyGuardrails(score);
    final allowed = policy['allowed'] == true;
    final tier = (score['tier'] ?? 'UNRATED') as String;

    if (!allowed) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('Not eligible to contract — $tier.')),
          ],
        ),
      );
    }

    final caps = Map<String, dynamic>.from(policy['caps'] ?? const {});
    final extras = List<String>.from(policy['extraChecks'] ?? const []);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Guardrails in effect'),
          const SizedBox(height: 6),
          if (caps.isNotEmpty)
            Wrap(
              spacing: 8,
              children: caps.entries
                  .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
                  .toList(),
            ),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: extras
                  .map((x) => Chip(
                        label: Text(x.replaceAll('_', ' ')),
                        backgroundColor: Colors.orange.shade100,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// Dart: Carrier Scorecard (ready to embed)
class CarrierScorecardCard extends ConsumerWidget {
  final String carrierId;
  final String? title; // optional heading
  final VoidCallback? onRefresh; // optional handler
  final void Function()? onRequestDocs; // CTA to request docs
  final void Function()? onOpenProfile; // CTA to open full profile

  const CarrierScorecardCard({
    super.key,
    required this.carrierId,
    this.title,
    this.onRefresh,
    this.onRequestDocs,
    this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncScore = ref.watch(carrierScoreProvider(carrierId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: asyncScore.when(
          loading: () => const Row(
            children: [
              SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Loading scorecard…'),
            ],
          ),
          error: (e, _) => Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to load scorecard: $e')),
              if (onRefresh != null)
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
            ],
          ),
          data: (score) {
            final tier = (score['tier'] ?? 'UNRATED') as String;
            final reasons = List<String>.from(score['reasons'] ?? const []);
            final components = Map<String, dynamic>.from(score['components'] ?? const {});
            final rawScore = score['score'] is num ? score['score'] as num : 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
                      )
                    else
                      Expanded(
                        child: Text('Carrier Scorecard', style: Theme.of(context).textTheme.titleMedium),
                      ),
                    CarrierTierBadge(tier: tier),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ScoreRing(score: rawScore, size: 64),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Composite score: ${rawScore.toStringAsFixed(0)} / 100',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          ReasonChips(reasons: reasons),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ComponentsTable(components: components),
                const SizedBox(height: 12),
                GuardrailsBanner(score: score),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onRequestDocs != null)
                      TextButton.icon(
                        onPressed: onRequestDocs,
                        icon: const Icon(Icons.assignment_turned_in_outlined),
                        label: const Text('Request Docs'),
                      ),
                    if (onOpenProfile != null)
                      TextButton.icon(
                        onPressed: onOpenProfile,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open Profile'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Dart: “Assign Flow” row helper (compact variant)
class CarrierScoreRow extends ConsumerWidget {
  final String carrierId;
  final VoidCallback? onTap;
  const CarrierScoreRow({super.key, required this.carrierId, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncScore = ref.watch(carrierScoreProvider(carrierId));
    return ListTile(
      onTap: onTap,
      leading: asyncScore.maybeWhen(
        data: (score) => CarrierTierBadge(tier: (score['tier'] ?? 'UNRATED') as String),
        orElse: () => const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      title: asyncScore.maybeWhen(
        data: (score) => Text('Score ${(score['score'] ?? 0).toString()}'),
        orElse: () => const Text('Loading…'),
      ),
      subtitle: asyncScore.maybeWhen(
        data: (score) {
          final reasons = List<String>.from(score['reasons'] ?? const []);
          final top = reasons.take(2).join(' • ');
          return Text(top.isEmpty ? 'No known issues' : top);
        },
        orElse: () => const SizedBox.shrink(),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/*
How to use

In a Carrier details page or Broker dashboard:

CarrierScorecardCard(
  carrierId: carrierId,
  title: 'SafetoContract',
  onRefresh: () => ref.refresh(carrierScoreProvider(carrierId)),
  onRequestDocs: () { /* open doc request sheet */ },
  onOpenProfile: () { /* navigate to full carrier profile */ },
)

In an Assign dialog list:

CarrierScoreRow(
  carrierId: carrierId,
  onTap: () { /* open details bottom sheet with CarrierScorecardCard */ },
)
*/
