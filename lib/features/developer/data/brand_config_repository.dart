import 'package:supabase_flutter/supabase_flutter.dart';

class BrandConfig {
  const BrandConfig({
    required this.brandKey,
    required this.appName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.borderColor,
  });

  final String brandKey;
  final String appName;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String backgroundColor;
  final String surfaceColor;
  final String textPrimaryColor;
  final String textSecondaryColor;
  final String borderColor;

  factory BrandConfig.fromMap(Map<String, dynamic> map) {
    return BrandConfig(
      brandKey: map['brand_key'] as String? ?? BrandConfigRepository.globalBrandKey,
      appName: map['app_name'] as String? ?? 'HALAL Food',
      primaryColor: map['primary_color'] as String? ?? '#0B6B3A',
      secondaryColor: map['secondary_color'] as String? ?? '#064B2A',
      accentColor: map['accent_color'] as String? ?? '#D4A72C',
      backgroundColor: map['background_color'] as String? ?? '#F8F9F7',
      surfaceColor: map['surface_color'] as String? ?? '#FFFFFF',
      textPrimaryColor: map['text_primary_color'] as String? ?? '#1A1A1A',
      textSecondaryColor: map['text_secondary_color'] as String? ?? '#6B6B6B',
      borderColor: map['border_color'] as String? ?? '#E5E5E5',
    );
  }

  Map<String, dynamic> toMap() => {
        'brand_key': brandKey,
        'app_name': appName,
        'primary_color': primaryColor,
        'secondary_color': secondaryColor,
        'accent_color': accentColor,
        'background_color': backgroundColor,
        'surface_color': surfaceColor,
        'text_primary_color': textPrimaryColor,
        'text_secondary_color': textSecondaryColor,
        'border_color': borderColor,
      };
}

class BrandConfigRepository {
  BrandConfigRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const globalBrandKey = 'halalfood';

  final SupabaseClient _supabase;

  Future<BrandConfig> getGlobalBrand() async {
    final row = await _supabase
        .from('brand_configs')
        .select()
        .eq('brand_key', globalBrandKey)
        .maybeSingle();

    if (row == null) {
      throw const PostgrestException(message: 'Global app branding not found.');
    }
    return BrandConfig.fromMap(row);
  }

  Future<void> saveGlobalBrand(BrandConfig config) async {
    final globalConfig = BrandConfig(
      brandKey: globalBrandKey,
      appName: config.appName,
      primaryColor: config.primaryColor,
      secondaryColor: config.secondaryColor,
      accentColor: config.accentColor,
      backgroundColor: config.backgroundColor,
      surfaceColor: config.surfaceColor,
      textPrimaryColor: config.textPrimaryColor,
      textSecondaryColor: config.textSecondaryColor,
      borderColor: config.borderColor,
    );
    await _supabase.from('brand_configs').upsert(globalConfig.toMap());
  }
}
