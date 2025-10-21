import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/models/app_role.dart';
import '../../common/services/user_profile_service.dart';
import '../../common/state/session_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  AppRole _role = AppRole.driver;
  bool _isPremium = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(userProfileServiceProvider);
      final p = await svc.fetchMyProfile();
      if (p != null) {
        _role = p.role;
        _isPremium = p.isPremium;
      } else {
        // If no profile row yet, use current session as defaults
        final s = ref.read(sessionProvider);
        _role = s.role;
        _isPremium = s.isPremium;
      }
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(userProfileServiceProvider);
      await svc.upsertMyProfile(role: _role, isPremium: _isPremium);
      // Update local session so UI reflects immediately
      ref
          .read(sessionProvider.notifier)
          .setAll(role: _role, isPremium: _isPremium);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const Text(
                    'Role',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<AppRole>(
                    value: _role,
                    items: const [
                      DropdownMenuItem(
                        value: AppRole.driver,
                        child: Text('Driver'),
                      ),
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
                        setState(() => _role = v ?? AppRole.driver),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Premium'),
                      const SizedBox(width: 12),
                      Switch(
                        value: _isPremium,
                        onChanged: (v) => setState(() => _isPremium = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      onPressed: _loading ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
