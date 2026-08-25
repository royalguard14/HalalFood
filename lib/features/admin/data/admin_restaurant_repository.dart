import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRestaurantRepository {
  final SupabaseClient _supabase;

  AdminRestaurantRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getRestaurantOwners() async {
    final response = await _supabase
        .from('profiles')
        .select('id, full_name, phone, role')
        .eq('role', 'restaurant_owner')
        .order('full_name', ascending: true);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> createRestaurant({
    required String name,
    String? ownerId,
    String? description,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? city,
    String? province,
    double? latitude,
    double? longitude,
    String? logoUrl,
    String? coverImageUrl,
    bool isActive = true,
    bool isFeatured = false,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'owner_id': ownerId,
      'description': _clean(description),
      'phone': _clean(phone),
      'email': _clean(email),
      'website': _clean(website),
      'address': _clean(address),
      'city': _clean(city),
      'province': _clean(province),
      'latitude': latitude,
      'longitude': longitude,
      'logo_url': _clean(logoUrl),
      'cover_image_url': _clean(coverImageUrl),
      'halal_status': 'unverified',
      'is_active': isActive,
      'is_featured': isFeatured,
      'average_rating': 0,
      'review_count': 0,
    };

    await _supabase.from('restaurants').insert(data);
  }

  Future<void> assignOwner({
    required String restaurantId,
    required String? ownerId,
  }) async {
    await _supabase
        .from('restaurants')
        .update({
          'owner_id': ownerId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', restaurantId);
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
