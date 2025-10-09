import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dashboards/base_dashboard.dart';

class LoadBoardDashboard extends BaseDashboard {
  const LoadBoardDashboard({super.key})
      : super(
          config: const DashboardConfig(
            id: 'load_board',
            title: 'Load Board Dashboard',
            defaultSize: Size(1400, 800),
          ),
        );

  @override
  ConsumerState<LoadBoardDashboard> createState() => _LoadBoardDashboardState();

  @override
  Widget buildDashboard(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_customize,
            size: 80,
            color: Colors.blue,
          ),
          SizedBox(height: 24),
          Text(
            'Load Board Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Coming soon...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _LoadBoardDashboardState extends BaseDashboardState<LoadBoardDashboard> {}
