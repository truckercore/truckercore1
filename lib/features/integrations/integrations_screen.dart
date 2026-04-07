// lib/features/integrations/integrations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../activity/activity_panel.dart';
import '../flags_usage/flags_usage_panel.dart';
import 'integrations_panel.dart';

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations & Ops')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntegrationsPanel(),
              SizedBox(height: 12),
              FlagsUsagePanel(),
              SizedBox(height: 12),
              ActivityPanel(),
            ],
          ),
        ),
      ),
    );
  }
}
