import 'package:flutter/material.dart';

class DashboardHelpScreen extends StatelessWidget {
  const DashboardHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            'Getting Started',
            'Navigate to Dashboards from the main menu. Click any dashboard card to open it in a new window.',
          ),
          _buildSection(
            context,
            'Window Layouts',
            'Use the grid icon in the dashboard toolbar to snap windows to predefined layouts (half-screen, quadrants, etc.).',
          ),
          _buildSection(
            context,
            'Keyboard Shortcuts',
            'F5: Refresh  |  Ctrl+,: Settings  |  F11: Fullscreen  |  Ctrl+W: Close',
          ),
          _buildSection(
            context,
            'Auto-Refresh',
            'Open Settings (Ctrl+,) inside any dashboard to configure auto-refresh interval and Always On Top.',
          ),
          _buildSection(
            context,
            'Managing Windows',
            'From the Dashboard Marketplace, tap the window icon in the app bar to view, focus, or close open dashboard windows.',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
