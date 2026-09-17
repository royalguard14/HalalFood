import 'package:flutter/material.dart';

import '../features/developer/data/brand_config_repository.dart';

class HalalFoodTheme {
  HalalFoodTheme._();

  static const Color primaryGreen = Color(0xFF0B6B3A);
  static const Color darkGreen = Color(0xFF064B2A);
  static const Color lightGreen = Color(0xFFEAF6EF);
  static const Color gold = Color(0xFFD4A72C);

  static const Color background = Color(0xFFF8F9F7);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color border = Color(0xFFE5E5E5);

  static ThemeData get light => fromBrand(null);

  static ThemeData fromBrand(BrandConfig? brand) {
    final primary = _parseColor(brand?.primaryColor, primaryGreen);
    final secondary = _parseColor(brand?.secondaryColor, darkGreen);
    final accent = _parseColor(brand?.accentColor, gold);
    final pageBackground = _parseColor(brand?.backgroundColor, background);
    final surfaceColor = _parseColor(brand?.surfaceColor, surface);
    final primaryText = _parseColor(brand?.textPrimaryColor, textPrimary);
    final secondaryText = _parseColor(brand?.textSecondaryColor, textSecondary);
    final borderColor = _parseColor(brand?.borderColor, border);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: accent,
      surface: surfaceColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pageBackground,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: primaryText,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: primaryText,
            displayColor: primaryText,
          ),
      extensions: <ThemeExtension<dynamic>>[
        HalalFoodBrandExtension(
          primary: primary,
          secondary: secondary,
          accent: accent,
          background: pageBackground,
          surface: surfaceColor,
          textPrimary: primaryText,
          textSecondary: secondaryText,
          border: borderColor,
        ),
      ],
    );
  }

  static Color _parseColor(String? value, Color fallback) {
    if (value == null) return fallback;
    final hex = value.replaceFirst('#', '');
    if (hex.length != 6) return fallback;
    final parsed = int.tryParse('FF$hex', radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }
}

class HalalFoodBrandExtension extends ThemeExtension<HalalFoodBrandExtension> {
  const HalalFoodBrandExtension({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  @override
  HalalFoodBrandExtension copyWith({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
  }) => HalalFoodBrandExtension(
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        accent: accent ?? this.accent,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        border: border ?? this.border,
      );

  @override
  HalalFoodBrandExtension lerp(
    ThemeExtension<HalalFoodBrandExtension>? other,
    double t,
  ) {
    if (other is! HalalFoodBrandExtension) return this;
    return HalalFoodBrandExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
