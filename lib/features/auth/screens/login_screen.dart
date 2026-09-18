import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../splash/splash_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Enabled only when the APK is intentionally built for owner/admin testing.
  // Keep this false for normal/production builds.
  static const bool _testLoginEnabled =
      bool.fromEnvironment('HALAL_TEST_LOGIN', defaultValue: false);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await _loginWithCredentials(_emailController.text.trim(), _passwordController.text);
  }

  Future<void> _quickLogin({required String label, required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label quick login is not configured. Add its credentials to your local .env file.')),
      );
      return;
    }
    await _loginWithCredentials(email, password);
  }

  Future<void> _loginWithCredentials(String email, String password) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      if (supabase.auth.currentSession != null) await supabase.auth.signOut();

      final response = await supabase.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw Exception('Unable to login.');

      // After authentication, always pass through SplashScreen so the centralized startup routing runs. This includes the one-time identity-verification gate for Customer, Driver and Restaurant Owner.
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to login: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text('Welcome back!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: HalalFoodTheme.textPrimary)),
                const SizedBox(height: 8),
                const Text('Login to continue to HALAL Food.', style: TextStyle(fontSize: 16, color: HalalFoodTheme.textSecondary)),
                const SizedBox(height: 36),
                const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Enter your email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please enter your email';
                    if (!value.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('Forgot password?'))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (kDebugMode || _testLoginEnabled) ...[
                  const SizedBox(height: 24),
                  _buildQuickLoginSection(),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600))),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text("Don't have an account? Register"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLoginSection() {
    final buttons = <Widget>[
      _quickButton('Admin', Icons.admin_panel_settings_outlined, Env.devAdminEmail, Env.devAdminPassword),
      _quickButton('Owner', Icons.storefront_outlined, Env.devOwnerEmail, Env.devOwnerPassword),
      _quickButton('User', Icons.person_outline, Env.devUserEmail, Env.devUserPassword),
      _quickButton('Developer', Icons.developer_mode_outlined, Env.devDeveloperEmail, Env.devDeveloperPassword),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.developer_mode, size: 18, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Text('TEMPORARY TEST LOGIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.amber.shade900, letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.9,
            children: buttons,
          ),
          const SizedBox(height: 8),
          Text('For development/testing only. Credentials stay in your local .env file.', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _quickButton(String label, IconData icon, String email, String password) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : () => _quickLogin(label: label, email: email, password: password),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
