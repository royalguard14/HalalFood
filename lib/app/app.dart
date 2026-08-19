import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/env.dart';
import '../features/cart/providers/cart_provider.dart';
import '../features/splash/splash_screen.dart';
import 'theme.dart';

class HalalFoodApp extends StatelessWidget {
  const HalalFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: Env.appName,
        theme: HalalFoodTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}