import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final bool showSpinner;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.showSpinner = false,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (showSpinner)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
