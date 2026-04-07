import 'package:flutter/material.dart';

import 'src/bootstrap/supabase_bootstrap.dart';
import 'ui/driver_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
  runApp(const TruckerCoreDriverApp());
}

class TruckerCoreDriverApp extends StatelessWidget {
  const TruckerCoreDriverApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TruckerCore Driver',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
        ),
        home: const DriverDashboard(),
        debugShowCheckedModeBanner: false,
      );
}
