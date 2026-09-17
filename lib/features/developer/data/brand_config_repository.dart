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
      brandKey: map['brand_key'] as String,
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

  final SupabaseClient _supabase;

  Future<BrandConfig> getBrand(String brandKey) async {
    final row = await _supabase
        .from('brand_configs')
        .select()
        .eq('brand_key', brandKey)
        .maybeSingle();

    if (row == null) {
      throw const PostgrestException(message: 'Brand configuration not found.');
    }
    return BrandConfig.fromMap(row);
  }

  Future<List<BrandConfig>> getAllBrands() async {
    final rows = await _supabase
        .from('brand_configs')
        .select()
        .order('app_name');
    return rows
        .map((row) => BrandConfig.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBrand(BrandConfig config) async {
    await _supabase.from('brand_configs').upsert(config.toMap());
  }
}
