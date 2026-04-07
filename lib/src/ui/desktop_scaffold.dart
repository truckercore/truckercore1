import 'package:flutter/material.dart';

class DesktopScaffold extends StatelessWidget {
  final Widget sidebar;
  final Widget content;
  const DesktopScaffold({super.key, required this.sidebar, required this.content});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1200;
        return Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints.tightFor(width: 280),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: sidebar,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Row(
                children: [
                  if (wide) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints.tightFor(width: 320),
                      child: Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        child: const _SidePane(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                  ],
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SidePane extends StatelessWidget {
  const _SidePane();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        Text('Filters'),
        SizedBox(height: 12),
        Text('Recent Loads'),
      ],
    );
  }
}
