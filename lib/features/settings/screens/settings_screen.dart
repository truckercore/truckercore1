import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_preferences.dart';
import '../services/preferences_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: preferencesAsync.when(
        data: (preferences) => _buildSettings(context, ref, preferences),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading settings: $e')),
      ),
    );
  }

  Widget _buildSettings(BuildContext context, WidgetRef ref, UserPreferences preferences) {
    return ListView(
      children: [
        _buildSection('Notifications', [
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive push notifications'),
            value: preferences.notificationsEnabled,
            onChanged: (value) => _updatePreference(
              ref,
              preferences.copyWith(notificationsEnabled: value),
            ),
          ),
          SwitchListTile(
            title: const Text('HOS Alerts'),
            subtitle: const Text('Alerts for hours of service limits'),
            value: preferences.hosAlertsEnabled,
            onChanged: (value) => _updatePreference(
              ref,
              preferences.copyWith(hosAlertsEnabled: value),
            ),
          ),
          SwitchListTile(
            title: const Text('Safety Alerts'),
            subtitle: const Text('Notifications for safety events'),
            value: preferences.safetyAlertsEnabled,
            onChanged: (value) => _updatePreference(
              ref,
              preferences.copyWith(safetyAlertsEnabled: value),
            ),
          ),
          SwitchListTile(
            title: const Text('Maintenance Alerts'),
            subtitle: const Text('Vehicle maintenance reminders'),
            value: preferences.maintenanceAlertsEnabled,
            onChanged: (value) => _updatePreference(
              ref,
              preferences.copyWith(maintenanceAlertsEnabled: value),
            ),
          ),
          SwitchListTile(
            title: const Text('Load Notifications'),
            subtitle: const Text('New load assignments and updates'),
            value: preferences.loadNotificationsEnabled,
            onChanged: (value) => _updatePreference(
              ref,
              preferences.copyWith(loadNotificationsEnabled: value),
            ),
          ),
        ]),
        _buildSection('Units & Display', [
          ListTile(
            title: const Text('Distance Unit'),
            subtitle: Text(preferences.distanceUnit == 'miles' ? 'Miles' : 'Kilometers'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showUnitPicker(
              context,
              'Distance Unit',
              const ['miles', 'km'],
              preferences.distanceUnit,
              (value) => _updatePreference(
                ref,
                preferences.copyWith(distanceUnit: value),
              ),
            ),
          ),
          ListTile(
            title: const Text('Temperature Unit'),
            subtitle: Text(preferences.temperatureUnit == 'fahrenheit' ? 'Fahrenheit' : 'Celsius'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showUnitPicker(
              context,
              'Temperature Unit',
              const ['fahrenheit', 'celsius'],
              preferences.temperatureUnit,
              (value) => _updatePreference(
                ref,
                preferences.copyWith(temperatureUnit: value),
              ),
            ),
          ),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(preferences.theme.toUpperCase()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showUnitPicker(
              context,
              'Theme',
              const ['light', 'dark', 'auto'],
              preferences.theme,
              (value) => _updatePreference(
                ref,
                preferences.copyWith(theme: value),
              ),
            ),
          ),
        ]),
        _buildSection('Navigation', [
          ListTile(
            title: const Text('Map Style'),
            subtitle: Text(preferences.mapStyle.toUpperCase()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showUnitPicker(
              context,
              'Map Style',
              const ['standard', 'satellite', 'hybrid'],
              preferences.mapStyle,
              (value) => _updatePreference(
                ref,
                preferences.copyWith(mapStyle: value),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Voice Navigation'),
            subtitle: const Text('Turn-by-turn voice directions'),
            value: preferences.voiceNavigationEnabled,
            onChanged: (value) => _updatePreference(
              ref,
              preferences.copyWith(voiceNavigationEnabled: value),
            ),
          ),
        ]),
        _buildSection('Offline Mode', [
          SwitchListTile(
            title: const Text('Offline Mode'),
            subtitle: const Text('Work without internet connection'),
            value: preferences.offlineMode,
            onChanged: (value) => _updatePreference(
              ref,
              preferences.copyWith(offlineMode: value),
            ),
          ),
          SwitchListTile(
            title: const Text('Auto-download Maps'),
            subtitle: const Text('Download maps for upcoming routes'),
            value: preferences.autoDownloadMaps,
            onChanged: (value) => _updatePreference(
              ref,
              preferences.copyWith(autoDownloadMaps: value),
            ),
          ),
          ListTile(
            title: const Text('Manage Offline Maps'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/offline-maps'),
          ),
        ]),
        _buildSection('Account', [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Security'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/security'),
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/help'),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () => _showSignOutDialog(context),
          ),
        ]),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showUnitPicker(
    BuildContext context,
    String title,
    List<String> options,
    String current,
    Function(String) onSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            final isSelected = option == current;
            return ListTile(
              title: Text(option.toUpperCase()),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.blue)
                  : const Icon(Icons.circle_outlined),
              selected: isSelected,
              onTap: () {
                onSelected(option);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _updatePreference(WidgetRef ref, UserPreferences preferences) async {
    try {
      await ref.read(preferencesServiceProvider).updatePreferences(preferences);
      ref.invalidate(userPreferencesProvider);
    } catch (_) {
      // Optionally show an error
    }
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement sign out
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
