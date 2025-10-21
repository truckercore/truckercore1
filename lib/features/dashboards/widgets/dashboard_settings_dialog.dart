import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dashboard_preferences.dart' as models;
import '../providers/dashboard_preferences_provider.dart';
import '../services/dashboard_analytics.dart';

class DashboardSettingsDialog extends ConsumerStatefulWidget {
  final String dashboardId;
  final String dashboardName;

  const DashboardSettingsDialog({
    super.key,
    required this.dashboardId,
    required this.dashboardName,
  });

  @override
  ConsumerState<DashboardSettingsDialog> createState() => _DashboardSettingsDialogState();
}

class _DashboardSettingsDialogState extends ConsumerState<DashboardSettingsDialog> {
  late models.DashboardPreferences _preferences;
  late int _refreshInterval;
  late bool _autoRefresh;
  late bool _alwaysOnTop;
  late bool _showNotifications;

  @override
  void initState() {
    super.initState();
    _preferences = ref.read(dashboardPreferencesNotifierProvider(widget.dashboardId)).getPreferences(widget.dashboardId);
    _refreshInterval = _preferences.refreshIntervalSeconds;
    _autoRefresh = _preferences.autoRefresh;
    _alwaysOnTop = _preferences.alwaysOnTop;
    _showNotifications = _preferences.showNotifications;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings),
          const SizedBox(width: 12),
          Expanded(child: Text('${widget.dashboardName} Settings')),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionTitle('Refresh Settings'),
              SwitchListTile(
                title: const Text('Auto Refresh'),
                subtitle: const Text('Automatically update dashboard data'),
                value: _autoRefresh,
                onChanged: (value) {
                  setState(() => _autoRefresh = value);
                },
              ),
              if (_autoRefresh) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Refresh Interval: ${_refreshInterval}s', style: Theme.of(context).textTheme.bodyMedium),
                      Slider(
                        value: _refreshInterval.toDouble(),
                        min: 5,
                        max: 300,
                        divisions: 59,
                        label: '${_refreshInterval}s',
                        onChanged: (value) => setState(() => _refreshInterval = value.toInt()),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('5s', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          Text('5m', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildSectionTitle('Window Behavior'),
              SwitchListTile(
                title: const Text('Always On Top'),
                subtitle: const Text('Keep window above other windows'),
                value: _alwaysOnTop,
                onChanged: (value) {
                  setState(() => _alwaysOnTop = value);
                },
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('Notifications'),
              SwitchListTile(
                title: const Text('Show Notifications'),
                subtitle: const Text('Display alerts for this dashboard'),
                value: _showNotifications,
                onChanged: (value) {
                  setState(() => _showNotifications = value);
                },
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('Sharing'),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Export Settings'),
                subtitle: const Text('Share dashboard settings as JSON'),
                onTap: _exportSettings,
              ),
              ListTile(
                leading: const Icon(Icons.file_open),
                title: const Text('Import Settings'),
                subtitle: const Text('Load settings from a JSON file'),
                onTap: _importSettings,
              ),

              _buildSectionTitle('Quick Actions'),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Reset Position & Size'),
                subtitle: const Text('Return to default window layout'),
                onTap: _resetWindowLayout,
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Reset All Settings'),
                subtitle: const Text('Restore default preferences'),
                onTap: _resetAllSettings,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saveSettings, child: const Text('Save')),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  void _resetWindowLayout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Window Layout'),
        content: const Text('This will reset the window position and size to defaults. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final updated = _preferences.copyWith();
              ref.read(dashboardPreferencesNotifierProvider(widget.dashboardId)).updatePreferences(widget.dashboardId, updated);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Window layout reset')));
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _resetAllSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text('This will reset all preferences to defaults. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final defaults = models.DashboardPreferences(dashboardId: widget.dashboardId);
              ref.read(dashboardPreferencesNotifierProvider(widget.dashboardId)).updatePreferences(widget.dashboardId, defaults);
              setState(() {
                _refreshInterval = defaults.refreshIntervalSeconds;
                _autoRefresh = defaults.autoRefresh;
                _alwaysOnTop = defaults.alwaysOnTop;
                _showNotifications = defaults.showNotifications;
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings reset to defaults')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final updated = _preferences.copyWith(
      refreshIntervalSeconds: _refreshInterval,
      autoRefresh: _autoRefresh,
      alwaysOnTop: _alwaysOnTop,
      showNotifications: _showNotifications,
    );
    await ref.read(dashboardPreferencesNotifierProvider(widget.dashboardId)).updatePreferences(widget.dashboardId, updated);
    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  Future<void> _exportSettings() async {
    try {
      final prefs = ref.read(dashboardPreferencesProvider(widget.dashboardId));
      final jsonStr = jsonEncode(prefs.toJson());
      await DashboardAnalytics.trackShare(widget.dashboardId);
      await Share.share(jsonStr, subject: '${widget.dashboardName} Settings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _importSettings() async {
    try {
      final assetBundle = DefaultAssetBundle.of(context);
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'txt']);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      String jsonStr;
      if (file.bytes != null) {
        jsonStr = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        jsonStr = await Future<String>.value(await assetBundle.loadString(file.path!));
      } else {
        throw 'Could not read file contents';
      }
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final imported = models.DashboardPreferences.fromJson(map);
      await ref.read(dashboardPreferencesNotifierProvider(widget.dashboardId)).updatePreferences(widget.dashboardId, imported);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings imported')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red));
    }
  }
}
