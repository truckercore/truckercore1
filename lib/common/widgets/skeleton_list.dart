import 'package:flutter/material.dart';

class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry spacing;

  const SkeletonList({
    super.key,
    this.count = 3,
    this.itemHeight = 72,
    this.spacing = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: List.generate(
        count,
        (i) => Container(
          height: itemHeight,
          margin: spacing,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
