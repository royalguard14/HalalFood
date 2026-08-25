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

    // Restaurant submission and halal verification are separate workflows.
    // Creating a restaurant does NOT create a halal_verifications row.
    await _supabase.from('restaurants').insert(clean);
  }

  Future<String?> getPendingVerificationId({
    required String restaurantId,
  }) async {
    final response = await _supabase
        .from('halal_verifications')
        .select('id')
        .eq('restaurant_id', restaurantId)
        .eq('status', 'pending')
        .limit(1)
        .maybeSingle();

    return response?['id']?.toString();
  }

  Future<bool> hasPendingVerification({
    required String restaurantId,
  }) async {
    return await getPendingVerificationId(restaurantId: restaurantId) != null;
  }

  Future<void> requestHalalVerification({
    required String restaurantId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final restaurant = await _supabase
        .from('restaurants')
        .select('id, owner_id, halal_status')
        .eq('id', restaurantId)
        .eq('owner_id', user.id)
        .maybeSingle();

    if (restaurant == null) {
      throw Exception('Restaurant not found or does not belong to this account.');
    }

    final halalStatus = restaurant['halal_status']?.toString() ?? 'unverified';
    if (halalStatus != 'unverified') {
      throw Exception('This restaurant already has a halal status.');
    }

    if (await hasPendingVerification(restaurantId: restaurantId)) {
      throw Exception('A halal verification request is already pending.');
    }

    await _supabase.from('halal_verifications').insert({
      'restaurant_id': restaurantId,
      'submitted_by': user.id,
      'status': 'pending',
    });
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
