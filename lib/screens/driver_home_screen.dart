import 'package:flutter/material.dart';
import '../widgets/driver_bottom_nav.dart';
import 'trip_screen.dart';
import 'alerts_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  final auth = AuthService();

  final List<Widget> _screens = const [
    _HomeTab(),
    TripScreen(),
    AlertsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: DriverBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TruckerCore',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      user?.email ?? 'Driver',
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF94A3B8)),
                  onPressed: () async {
                    await AuthService().signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Quick action cards
            _QuickActionCard(
              icon: Icons.local_shipping,
              title: 'Start Trip',
              subtitle: 'Track miles, fuel & tolls automatically',
              color: const Color(0xFF16A34A),
              onTap: () {
                // Navigate to trip tab
              },
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.notifications_active,
              title: 'View Alerts',
              subtitle: 'Hazards, inspections, HOS warnings',
              color: const Color(0xFFD97706),
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.bar_chart,
              title: 'My Stats',
              subtitle: 'Miles driven, expenses, IFTA',
              color: const Color(0xFF2563EB),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF475569)),
          ],
        ),
      ),
    );
  }
}