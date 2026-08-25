import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerRestaurantRepository {
  final SupabaseClient _supabase;

  OwnerRestaurantRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyRestaurants() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final response = await _supabase
        .from('restaurants')
        .select('id, name, description, phone, email, address, city, province, is_active, halal_status, created_at')
        .eq('owner_id', user.id)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> submitRestaurant({
    required String name,
    String? description,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? province,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final clean = <String, dynamic>{
      'name': name.trim(),
      'owner_id': user.id,
      'description': _clean(description),
      'phone': _clean(phone),
      'email': _clean(email),
      'address': _clean(address),
      'city': _clean(city),
      'province': _clean(province),
      'halal_status': 'unverified',
      'is_active': false,
      'is_featured': false,
      'average_rating': 0,
      'review_count': 0,
    };

    await _supabase.from('restaurants').insert(clean);
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
