import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class DesktopWindowShell extends StatelessWidget {
  final Widget child;
  const DesktopWindowShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WindowBorder(
        color: Theme.of(context).dividerColor,
        width: 1,
        child: Column(
          children: [
            const DesktopTitleBar(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class DesktopTitleBar extends StatelessWidget {
  const DesktopTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Container(
      color: color.surfaceContainerHighest,
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: MoveWindow(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      'TruckerCore Desktop',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: 12),
                    const _QuickActions(),
                  ],
                ),
              ),
            ),
          ),
          const WindowButtons(),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Open CSV Import Wizard')),
            );
          },
          icon: const Icon(Icons.upload_file, size: 16),
          label: const Text('Import CSV'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Open Print Preview')),
            );
          },
          icon: const Icon(Icons.print, size: 16),
          label: const Text('Print'),
        ),
      ],
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final hover = Theme.of(context).hoverColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MinimizeWindowButton(colors: WindowButtonColors(iconNormal: Colors.grey[700])),
        MaximizeWindowButton(colors: WindowButtonColors(iconNormal: Colors.grey[700])),
        CloseWindowButton(
          onPressed: () {
            appWindow.close();
          },
          colors: WindowButtonColors(
            mouseOver: hover,
            iconNormal: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
