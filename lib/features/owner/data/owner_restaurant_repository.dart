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
        .select(
          'id, name, description, phone, email, address, city, province, '
          'is_active, halal_status, created_at',
        )
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

    // An owner-submitted restaurant is automatically placed in the
    // admin verification queue. The restaurant stays inactive until an
    // admin reviews and approves it.
    final restaurant = await _supabase
        .from('restaurants')
        .insert(clean)
        .select('id')
        .single();

    final restaurantId = restaurant['id']?.toString();
    if (restaurantId == null || restaurantId.isEmpty) {
      throw Exception('Restaurant was created but no restaurant ID was returned.');
    }

    try {
      await _supabase.from('halal_verifications').insert({
        'restaurant_id': restaurantId,
        'submitted_by': user.id,
        'status': 'pending',
      });
    } catch (e) {
      // Avoid leaving a restaurant that the owner believes was submitted
      // without its corresponding admin review request.
      try {
        await _supabase
            .from('restaurants')
            .delete()
            .eq('id', restaurantId);
      } catch (_) {
        // Preserve the original verification error below.
      }
      throw Exception('Unable to submit the restaurant for admin verification: $e');
    }
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
