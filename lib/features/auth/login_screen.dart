import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/app_role.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/user_profile_service.dart';
import '../../../common/state/session_provider.dart';
import '../../common/widgets/app_background.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  AppRole _selectedRole = AppRole.driver;
  bool _isPremium = false;
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    // Basic validation
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your email.')));
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password.')),
      );
      return;
    }

    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    final profiles = ref.read(userProfileServiceProvider);

    try {
      await auth.signIn(email, pass);
      await profiles.upsertMyProfile(
        role: _selectedRole,
        isPremium: _isPremium,
      );
      final p = await profiles.fetchMyProfile();
      if (p != null) {
        ref
            .read(sessionProvider.notifier)
            .setAll(role: p.role, isPremium: p.isPremium);
      } else {
        ref
            .read(sessionProvider.notifier)
            .setAll(role: _selectedRole, isPremium: _isPremium);
      }
      if (!mounted) return;
      // Redirect by role: drivers go to dedicated dashboard path
      final session = ref.read(sessionProvider);
      if (session.role == AppRole.driver) {
        context.go('/dashboard/driver');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    if (_busy) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    // Basic validation
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your email.')));
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password.')),
      );
      return;
    }

    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    try {
      await auth.signUp(email, pass);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign up successful. Now tap Sign In.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: AppBackground(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Email'),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            const Text('Password'),
            TextField(controller: _passCtrl, obscureText: true),
            const SizedBox(height: 16),
            const Text('Select your role:'),
            const SizedBox(height: 8),
            DropdownButton<AppRole>(
              value: _selectedRole,
              items: const [
                DropdownMenuItem(value: AppRole.driver, child: Text('Driver')),
                DropdownMenuItem(
                  value: AppRole.fleetManager,
                  child: Text('Fleet Manager'),
                ),
                DropdownMenuItem(
                  value: AppRole.ownerOperator,
                  child: Text('Owner Operator'),
                ),
                DropdownMenuItem(
                  value: AppRole.broker,
                  child: Text('Freight Broker'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _selectedRole = v ?? AppRole.driver),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Premium plan'),
                const SizedBox(width: 12),
                Switch(
                  value: _isPremium,
                  onChanged: (v) => setState(() => _isPremium = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const CircularProgressIndicator()
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _signUp,
                    child: const Text('Sign Up'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
