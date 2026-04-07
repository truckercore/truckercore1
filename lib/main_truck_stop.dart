import 'package:flutter/material.dart';

import 'src/bootstrap/supabase_bootstrap.dart';
import 'ui/truck_stop_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
  runApp(const TruckerCoreTruckStopApp());
}

class TruckerCoreTruckStopApp extends StatelessWidget {
  const TruckerCoreTruckStopApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TruckerCore Truck Stop',
        theme: ThemeData(primarySwatch: Colors.orange),
        home: const TruckStopDashboard(),
        debugShowCheckedModeBanner: false,
      );
}
