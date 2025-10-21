import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DashboardShortcuts {
  static const refresh = SingleActivator(LogicalKeyboardKey.f5);
  static const settings = SingleActivator(LogicalKeyboardKey.comma, control: true);
  static const toggleFullscreen = SingleActivator(LogicalKeyboardKey.f11);
  static const closeWindow = SingleActivator(LogicalKeyboardKey.keyW, control: true);
  static const zoomIn = SingleActivator(LogicalKeyboardKey.equal, control: true);
  static const zoomOut = SingleActivator(LogicalKeyboardKey.minus, control: true);
  static const resetZoom = SingleActivator(LogicalKeyboardKey.digit0, control: true);

  static SingleActivator quickLaunch(int number) {
    return SingleActivator(LogicalKeyboardKey(0x00000030 + number), control: true);
  }
}

class DashboardShortcutsWidget extends StatelessWidget {
  final String dashboardId;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onClose;
  final Widget child;

  const DashboardShortcutsWidget({
    super.key,
    required this.dashboardId,
    required this.onRefresh,
    required this.onSettings,
    required this.child,
    this.onToggleFullscreen,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        DashboardShortcuts.refresh: onRefresh,
        DashboardShortcuts.settings: onSettings,
        if (onToggleFullscreen != null) DashboardShortcuts.toggleFullscreen: onToggleFullscreen!,
        if (onClose != null) DashboardShortcuts.closeWindow: onClose!,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

class KeyboardShortcutsHelpDialog extends StatelessWidget {
  const KeyboardShortcutsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard),
          SizedBox(width: 12),
          Text('Keyboard Shortcuts'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSection('General', const [
                _ShortcutItem('F5', 'Refresh dashboard'),
                _ShortcutItem('Ctrl + ,', 'Open settings'),
                _ShortcutItem('F11', 'Toggle fullscreen'),
                _ShortcutItem('Ctrl + W', 'Close window'),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String keys;
  final String description;
  const _ShortcutItem(this.keys, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(keys, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(description, style: TextStyle(color: Colors.grey[400]))),
        ],
      ),
    );
  }
}
