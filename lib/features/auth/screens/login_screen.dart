import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Using compile-time flag for demo accounts

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirectTo;

  const LoginScreen({super.key, this.redirectTo});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw Exception('Login failed: No user returned');
      }

      // Get user role
      final user = response.user!;
      final primaryRole = user.userMetadata?['primary_role'] as String?;
      final roles = user.userMetadata?['roles'] as List?;

      dev.log('[auth] Login successful: ${user.email}, role=$primaryRole', name: 'auth');

      if (!mounted) return;

      // Route based on role or redirect
      if (widget.redirectTo != null && widget.redirectTo!.isNotEmpty) {
        context.go(widget.redirectTo!);
      } else if (primaryRole != null) {
        _routeByRole(primaryRole);
      } else if (roles != null && roles.isNotEmpty) {
        _routeByRole(roles.first.toString());
      } else {
        // Default to driver if no role specified
        context.go('/driver/dashboard');
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
      dev.log('[auth] Login failed: ${e.message}', level: 1000, name: 'auth');
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
      dev.log('[auth] Login error: $e', level: 1000, name: 'auth');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _routeByRole(String role) {
    switch (role) {
      case 'driver':
        context.go('/driver/dashboard');
        break;
      case 'owner_operator':
        context.go('/owner-operator/dashboard');
        break;
      case 'fleet_manager':
        context.go('/fleet-manager/dashboard');
        break;
      default:
        context.go('/driver/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Title
                    Icon(
                      Icons.local_shipping,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TruckerCore',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fleet Management System',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !_isLoading,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : () => context.push('/auth/forgot-password'),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 16),

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : () => context.push('/auth/signup'),
                          child: const Text('Sign Up'),
                        ),
                      ],
                    ),

                    // Demo Accounts (for testing)
                    if (const bool.fromEnvironment('USE_MOCK_DATA')) ...[
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Demo Accounts',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      _DemoAccountButton(
                        role: 'Driver',
                        email: 'driver@demo.com',
                        onTap: () {
                          _emailController.text = 'driver@demo.com';
                          _passwordController.text = 'demo123';
                        },
                      ),
                      _DemoAccountButton(
                        role: 'Owner Operator',
                        email: 'owner@demo.com',
                        onTap: () {
                          _emailController.text = 'owner@demo.com';
                          _passwordController.text = 'demo123';
                        },
                      ),
                      _DemoAccountButton(
                        role: 'Fleet Manager',
                        email: 'manager@demo.com',
                        onTap: () {
                          _emailController.text = 'manager@demo.com';
                          _passwordController.text = 'demo123';
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoAccountButton extends StatelessWidget {
  final String role;
  final String email;
  final VoidCallback onTap;

  const _DemoAccountButton({
    required this.role,
    required this.email,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(12),
      ),
      child: Row(
        children: [
          Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }
}
