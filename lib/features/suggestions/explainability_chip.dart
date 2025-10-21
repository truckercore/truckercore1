// lib/features/suggestions/explainability_chip.dart
import 'package:flutter/material.dart';

/// Renders up to 4 concise explainability chips for a suggestion.
/// Largest positives first: pass reasons already prioritized or include leading markers like "+18% market".
class ExplainabilityChips extends StatelessWidget {
  const ExplainabilityChips({super.key, required this.reasons, this.max = 4, this.dense = false});
  final List<String> reasons;
  final int max;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) return const SizedBox.shrink();
    final top = reasons.take(max.clamp(1, 6)).toList();
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return Wrap(
      spacing: 6,
      runSpacing: dense ? 2 : 4,
      children: [
        for (final r in top)
          Tooltip(
            message: r,
            waitDuration: const Duration(milliseconds: 250),
            child: Semantics(
              button: true,
              label: 'Reason: $r',
              child: Chip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
                label: Text(_shorten(r), style: textStyle),
              ),
            ),
          ),
      ],
    );
  }

  String _shorten(String s) {
    // Keep chips concise; aim for ~12–18 chars.
    const maxChars = 18;
    final t = s.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars - 1).trimRight()}…';
  }
}
