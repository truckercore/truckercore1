import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnon = const String.fromEnvironment('SUPABASE_ANON');

  if (supabaseUrl.isNotEmpty && supabaseAnon.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnon,
    );
  }

  runApp(const TruckerCoreMobile());
}

class TruckerCoreMobile extends StatelessWidget {
  const TruckerCoreMobile({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckerCore',
      theme: ThemeData(useMaterial3: true),
      home: const _AuthRequired(child: HomeScreen()),
    );
  }
}

class _AuthRequired extends StatefulWidget {
  final Widget child;
  const _AuthRequired({required this.child});
  @override
  State<_AuthRequired> createState() => _AuthRequiredState();
}

class _AuthRequiredState extends State<_AuthRequired> {
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Login / Sign up'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signInWithOtp(
                  email: 'demo@example.com',
                  emailRedirectTo: 'io.supabase.flutter://login-callback/',
                );
              },
              child: const Text('Send Magic Link'),
            ),
          ]),
        ),
      );
    }
    return widget.child;
  }
}
