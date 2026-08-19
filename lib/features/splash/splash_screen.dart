import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

Timer(const Duration(seconds: 3), () {
  if (!mounted) return;

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => const OnboardingScreen(),
    ),
  );
});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HalalFoodTheme.primaryGreen,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  size: 62,
                  color: HalalFoodTheme.primaryGreen,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'HALAL FOOD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
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
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
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