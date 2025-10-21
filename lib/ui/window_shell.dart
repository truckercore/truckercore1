// lib/ui/window_shell.dart
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
            const _DesktopTitleBar(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _DesktopTitleBar extends StatelessWidget {
  const _DesktopTitleBar();

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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TruckerCore Desktop',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ),
          ),
          MinimizeWindowButton(),
          MaximizeWindowButton(),
          CloseWindowButton(
            onPressed: () => appWindow.close(),
          ),
        ],
      ),
    );
  }
}
