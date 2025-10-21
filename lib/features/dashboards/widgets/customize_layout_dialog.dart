import 'package:flutter/material.dart';

import '../models/dashboard_layout_config.dart';

class CustomizeLayoutDialog extends StatefulWidget {
  final DashboardLayoutConfig currentConfig;
  final void Function(DashboardLayoutConfig) onSave;

  const CustomizeLayoutDialog({
    super.key,
    required this.currentConfig,
    required this.onSave,
  });

  @override
  State<CustomizeLayoutDialog> createState() => _CustomizeLayoutDialogState();
}

class _CustomizeLayoutDialogState extends State<CustomizeLayoutDialog> {
  late List<String> _visible;
  late String _sortBy;
  late bool _showInactive;

  static const _allMetrics = <String>['performance', 'safety', 'fuel', 'ontime'];

  @override
  void initState() {
    super.initState();
    _visible = List<String>.from(widget.currentConfig.visibleMetrics);
    _sortBy = widget.currentConfig.sortBy;
    _showInactive = widget.currentConfig.showInactive;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Customize Dashboard'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visible metrics', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allMetrics.map((m) {
                final selected = _visible.contains(m);
                return FilterChip(
                  label: Text(_label(m)),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        if (!_visible.contains(m)) _visible.add(m);
                      } else {
                        _visible.remove(m);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Sort by', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _sortBy,
              items: _allMetrics
                  .map((m) => DropdownMenuItem<String>(value: m, child: Text(_label(m))))
                  .toList(),
              onChanged: (v) => setState(() => _sortBy = v ?? _sortBy),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show inactive'),
              subtitle: const Text('Include inactive items in lists'),
              value: _showInactive,
              onChanged: (v) => setState(() => _showInactive = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final cfg = DashboardLayoutConfig(
              visibleMetrics: _visible.isEmpty ? _allMetrics : _visible,
              sortBy: _sortBy,
              showInactive: _showInactive,
            );
            widget.onSave(cfg);
            Navigator.of(context).pop(true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _label(String key) {
    switch (key) {
      case 'performance':
        return 'Overall';
      case 'safety':
        return 'Safety';
      case 'fuel':
        return 'Fuel';
      case 'ontime':
        return 'On-Time';
      default:
        return key;
    }
  }
}
