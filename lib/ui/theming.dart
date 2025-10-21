import 'package:flutter/material.dart';

class CardThemeWrapper extends StatelessWidget {
  final ColorScheme? colorSchemeOverride;
  final Widget child;

  const CardThemeWrapper({
    super.key,
    required this.child,
    this.colorSchemeOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (colorSchemeOverride == null) return child;
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(colorScheme: colorSchemeOverride),
      child: child,
    );
  }
}
