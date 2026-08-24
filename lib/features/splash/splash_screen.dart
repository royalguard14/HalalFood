
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../auth/screens/login_screen.dart';
import '../home/screens/home_screen.dart';
import '../owner/screens/owner_dashboard_screen.dart';
import '../admin/screens/admin_dashboard_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }


  void _goToAdminDashboard() {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) =>
          const AdminDashboardScreen(),
    ),
  );
}

  Future<void> _checkSession() async {
    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (!mounted) return;

    final supabase =
        Supabase.instance.client;

    final session =
        supabase.auth.currentSession;

    if (session == null) {
      _goToLogin();
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      if (!mounted) return;

      final role =
          profile?['role']?.toString();

if (role == 'admin') {
  _goToAdminDashboard();
} else if (role == 'restaurant_owner') {
  _goToOwnerDashboard();
} else {
  _goToHome();
}
    } catch (e) {
      debugPrint(
        'Unable to load user role: $e',
      );

      if (!mounted) return;

      // If the profile cannot be loaded,
      // send the user to the normal customer side.
      _goToHome();
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  void _goToOwnerDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            const OwnerDashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          HalalFoodTheme.primaryGreen,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset:
                          const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons
                      .restaurant_menu_rounded,
                  size: 62,
                  color:
                      HalalFoodTheme
                          .primaryGreen,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'HALAL FOOD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Halal food, made easy.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 45),

              const SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<
                          Color>(
                    Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

