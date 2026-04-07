import 'package:flutter/material.dart';

/// Compact overflow menu for the AppBar to centralize extra actions.
/// Consumers pass callbacks for each supported action; null callbacks hide the item.
class AppBarMoreMenu extends StatelessWidget {
  final VoidCallback? onDotInspection;
  final VoidCallback? onRoutePlanning;
  final VoidCallback? onLogout;

  const AppBarMoreMenu({super.key, this.onDotInspection, this.onRoutePlanning, this.onLogout});

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      if (onDotInspection != null)
        _MoreItem('DOT Inspection Mode', Icons.verified_user_outlined, onDotInspection!),
      if (onRoutePlanning != null)
        _MoreItem('Route Planning', Icons.alt_route, onRoutePlanning!),
      if (onLogout != null) _MoreItem('Logout', Icons.logout, onLogout!),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<int>(
      tooltip: 'More',
      onSelected: (i) => items[i].onTap(),
      itemBuilder: (ctx) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(items[i].icon, size: 20),
                const SizedBox(width: 8),
                Text(items[i].label),
              ],
            ),
          )
      ],
    );
  }
}

class _MoreItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _MoreItem(this.label, this.icon, this.onTap);
}
