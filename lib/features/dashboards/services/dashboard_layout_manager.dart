import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

enum DashboardLayout {
  fullscreen,
  leftHalf,
  rightHalf,
  topHalf,
  bottomHalf,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

class DashboardLayoutManager {
  static Future<void> applyLayout(DashboardLayout layout) async {
    final screen = await _getScreenSize();
    final Rect targetRect = _calculateTargetRect(layout, screen);
    await windowManager.setBounds(targetRect);
  }

  static Future<Size> _getScreenSize() async {
    final display = await ScreenRetriever.instance.getPrimaryDisplay();
    final sz = display.size;
    return Size(sz.width.toDouble(), sz.height.toDouble());
  }

  static Rect _calculateTargetRect(DashboardLayout layout, Size screen) {
    const padding = 8.0;

    switch (layout) {
      case DashboardLayout.fullscreen:
        return Rect.fromLTWH(0, 0, screen.width, screen.height);
      case DashboardLayout.leftHalf:
        return Rect.fromLTWH(padding, padding, screen.width / 2 - padding * 1.5, screen.height - padding * 2);
      case DashboardLayout.rightHalf:
        return Rect.fromLTWH(screen.width / 2 + padding / 2, padding, screen.width / 2 - padding * 1.5, screen.height - padding * 2);
      case DashboardLayout.topHalf:
        return Rect.fromLTWH(padding, padding, screen.width - padding * 2, screen.height / 2 - padding * 1.5);
      case DashboardLayout.bottomHalf:
        return Rect.fromLTWH(padding, screen.height / 2 + padding / 2, screen.width - padding * 2, screen.height / 2 - padding * 1.5);
      case DashboardLayout.topLeft:
        return Rect.fromLTWH(padding, padding, screen.width / 2 - padding * 1.5, screen.height / 2 - padding * 1.5);
      case DashboardLayout.topRight:
        return Rect.fromLTWH(screen.width / 2 + padding / 2, padding, screen.width / 2 - padding * 1.5, screen.height / 2 - padding * 1.5);
      case DashboardLayout.bottomLeft:
        return Rect.fromLTWH(padding, screen.height / 2 + padding / 2, screen.width / 2 - padding * 1.5, screen.height / 2 - padding * 1.5);
      case DashboardLayout.bottomRight:
        return Rect.fromLTWH(screen.width / 2 + padding / 2, screen.height / 2 + padding / 2, screen.width / 2 - padding * 1.5, screen.height / 2 - padding * 1.5);
      case DashboardLayout.center:
        const width = 1200.0;
        const height = 800.0;
        return Rect.fromLTWH((screen.width - width) / 2, (screen.height - height) / 2, width, height);
    }
  }

  static Future<void> snapToGrid() async {
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    final screen = await _getScreenSize();

    final centerX = position.dx + size.width / 2;
    final centerY = position.dy + size.height / 2;

    final isLeft = centerX < screen.width / 2;
    final isTop = centerY < screen.height / 2;

    DashboardLayout layout;
    if (isLeft && isTop) {
      layout = DashboardLayout.topLeft;
    } else if (!isLeft && isTop) {
      layout = DashboardLayout.topRight;
    } else if (isLeft && !isTop) {
      layout = DashboardLayout.bottomLeft;
    } else {
      layout = DashboardLayout.bottomRight;
    }

    await applyLayout(layout);
  }
}

class DashboardLayoutMenu extends StatelessWidget {
  const DashboardLayoutMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DashboardLayout>(
      icon: const Icon(Icons.grid_view),
      tooltip: 'Window Layout',
      onSelected: (layout) async {
        await DashboardLayoutManager.applyLayout(layout);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Applied ${_layoutName(layout)} layout'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: DashboardLayout.fullscreen,
          child: Row(children: [Icon(Icons.fullscreen, size: 20), SizedBox(width: 12), Text('Fullscreen')]),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: DashboardLayout.leftHalf,
          child: Row(children: [Icon(Icons.border_left, size: 20), SizedBox(width: 12), Text('Left Half')]),
        ),
        PopupMenuItem(
          value: DashboardLayout.rightHalf,
          child: Row(children: [Icon(Icons.border_right, size: 20), SizedBox(width: 12), Text('Right Half')]),
        ),
        PopupMenuItem(
          value: DashboardLayout.topHalf,
          child: Row(children: [Icon(Icons.border_top, size: 20), SizedBox(width: 12), Text('Top Half')]),
        ),
        PopupMenuItem(
          value: DashboardLayout.bottomHalf,
          child: Row(children: [Icon(Icons.border_bottom, size: 20), SizedBox(width: 12), Text('Bottom Half')]),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: DashboardLayout.topLeft,
          child: Row(children: [Icon(Icons.vertical_align_top, size: 20), SizedBox(width: 12), Text('Top Left')]),
        ),
        PopupMenuItem(
          value: DashboardLayout.topRight,
          child: Row(children: [Icon(Icons.vertical_align_top, size: 20), SizedBox(width: 12), Text('Top Right')]),
        ),
        PopupMenuItem(
          value: DashboardLayout.bottomLeft,
          child: Row(children: [Icon(Icons.vertical_align_bottom, size: 20), SizedBox(width: 12), Text('Bottom Left')]),
        ),
        PopupMenuItem(
          value: DashboardLayout.bottomRight,
          child: Row(children: [Icon(Icons.vertical_align_bottom, size: 20), SizedBox(width: 12), Text('Bottom Right')]),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: DashboardLayout.center,
          child: Row(children: [Icon(Icons.center_focus_strong, size: 20), SizedBox(width: 12), Text('Center')]),
        ),
      ],
    );
  }

  String _layoutName(DashboardLayout layout) {
    return layout.toString().split('.').last.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').trim();
  }
}
