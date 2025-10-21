import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/gating/feature_gate.dart';
import '../../core/entitlements/entitlements_service.dart';
import '../../core/updates/ios_update.dart' show checkIosUpdate;
import '../../core/updates/update_service.dart';
import '../onboarding/legal_onboarding.dart';
import '../paywall/paywall_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final EntitlementsService entSvc;
  final updater = UpdateService();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final sb = Supabase.instance.client;
    entSvc = EntitlementsService(sb);
    entSvc.init().then((_) async {
      if (Platform.isAndroid) {
        await updater.checkAndUpdate();
      } else if (Platform.isIOS) {
        await checkIosUpdate(appStoreAppId: 'YOUR_APP_ID');
      }
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    entSvc.dispose();
    super.dispose();
  }

  void _upsell() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!entSvc.entitlements.legalVerified) {
      return const LegalOnboardingScreen();
    }
    final ent = entSvc.entitlements;
    final isDriver = ent.role == AppRole.driver;
    final isOwnerOp = ent.role == AppRole.ownerOperator;

    return Scaffold(
      appBar: AppBar(title: Text(isOwnerOp ? 'Owner-Operator' : isDriver ? 'Driver' : 'TruckerCore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isDriver) const Text('Driver Tools'),
          if (isOwnerOp) const Text('Owner-Operator Tools'),
          const SizedBox(height: 12),
          Card(child: ListTile(title: const Text('Route Planner'), onTap: () {})),
          FeatureGate(
            entitlements: ent,
            minTier: AppTier.premium,
            onUpsell: _upsell,
            child: Card(child: ListTile(title: const Text('Fuel + Toll Optimizer (Pro)'), onTap: () {})),
          ),
          if (isOwnerOp)
            FeatureGate(
              entitlements: ent,
              minTier: AppTier.premium,
              onUpsell: _upsell,
              child: Card(child: ListTile(title: const Text('Expense Analytics (Owner-Op Pro)'), onTap: () {})),
            ),
        ],
      ),
    );
  }
}
