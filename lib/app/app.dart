import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/cart/providers/cart_provider.dart';
import '../features/developer/providers/brand_theme_provider.dart';
import '../features/splash/splash_screen.dart';

class HalalFoodApp extends StatelessWidget {
  const HalalFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(
          create: (_) => BrandThemeProvider()..load(),
        ),
      ],
      child: Consumer<BrandThemeProvider>(
        builder: (context, brandTheme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: brandTheme.config?.appName ?? 'HALAL Food',
            theme: brandTheme.theme,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
