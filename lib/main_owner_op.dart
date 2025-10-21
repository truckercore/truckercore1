import 'package:flutter/material.dart';

import 'src/bootstrap/supabase_bootstrap.dart';
import 'ui/owner_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
  runApp(const TruckerCoreOwnerOpApp());
}

class TruckerCoreOwnerOpApp extends StatelessWidget {
  const TruckerCoreOwnerOpApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TruckerCore Owner-Operator',
        theme: ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF16A34A), // green
          useMaterial3: true,
        ),
        home: const OwnerOpDashboard(),
        debugShowCheckedModeBanner: false,
      );
}
